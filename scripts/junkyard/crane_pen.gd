class_name CranePen
extends Node2D
## The crane pen: the dug-out yard behind the junkyard where the scrap crane
## actually lives, and where the player drives it.
##
## This is a place of its own rather than a corner of the junkyard because the
## two want opposite things. The yard has to stay calm — the player drives
## through it, so its heap is art-directed and asleep (see junkyard_pile.gd) —
## while a heap worth digging in has to be real: gravity on, junk falling and
## stacking (see trash_heap.gd). Separate scenes, separate physics, no
## compromise either way.
##
## The pen owns the framing and the bookkeeping, not the game. It draws the lot
## (backdrop, ground, the pit the junk is tipped into), wires the crane's
## `dug`/`missed`/`denied` reports to a wallet and a HUD, and banks what comes
## up: a real part into the spare-parts stash, plain junk into scrap. Deciding
## what the jaws actually close on is the heap's job, and driving them there is
## the player's.
##
## Fitting the pit out is a two-part contract, the same one junkyard_yard.gd has
## with its walls: `pit_rect` here is what gets painted, and the pen's own
## StaticBody2D walls are what actually holds the junk in. Move one, move the
## other.

## The dug-out area junk is tipped into, in this node's own space: the scene's
## walls sit on its left and right edges.
@export var pit_rect: Rect2 = Rect2(-380.0, 0.0, 680.0, 260.0)
## Where the player goes when the dig is over. A visit is one dig, so the pen
## kicks them back to the yard as soon as the claw is up — empty this and it
## leaves them standing in the pen instead, which is what the smoke test wants
## when it drives several digs in one visit.
@export_file("*.tscn") var exit_scene: String = "res://scenes/junkyard/junkyard.tscn"
## How long the haul stays on screen before the scene changes. Long enough to
## read the summary, short enough not to feel like a loading screen.
@export var exit_delay: float = 1.7

@export_group("Colors")
@export var sky_color: Color = Color(0.34, 0.36, 0.37, 1)
@export var wall_color: Color = Color(0.36, 0.31, 0.26, 1)
@export var wall_dark: Color = Color(0.28, 0.24, 0.2, 1)
@export var dirt_color: Color = Color(0.42, 0.36, 0.26, 1)
@export var pit_color: Color = Color(0.3, 0.25, 0.19, 1)
@export var kerb_color: Color = Color(0.45, 0.34, 0.22, 1)
@export var stain_color: Color = Color(0.16, 0.14, 0.11, 0.4)

const POPUP_RISE := 66.0
const POPUP_LIFETIME := 1.2
const POPUP_COLOR := Color(0.98, 0.88, 0.5, 1)
## Where the haul banner sits, in this node's space: over the pit, clear of the
## HUD line along the bottom of the screen. It's the banner's centre, so it
## stays put over the heap however long the summary turns out to be.
const POPUP_AT := Vector2(-20.0, -330.0)
const POPUP_WIDTH := 900.0

@onready var _crane: CraneRig = $Yard/Crane
@onready var _heap: TrashHeap = $Yard/Heap
@onready var _money: Label = $UI/Money
@onready var _line: Label = $UI/Line
@onready var _hint: Label = $UI/Hint

## The pieces the current dig brought up: part names, and the scrap the plain
## junk weighed in as. Filled by `dug` as it fires once per piece, read out and
## cleared by `_on_dig_finished` — one dig, one summary.
var _haul: Array[String] = []
var _haul_scrap: int = 0

func _ready() -> void:
	_crane.dug.connect(_on_dug)
	_crane.missed.connect(_on_missed)
	_crane.denied.connect(_on_denied)
	_crane.dig_finished.connect(_on_dig_finished)
	_hint.text = "A / D  roll the claw over the heap     Space  sink it and haul up what it grabs ($%d)     Esc  leave" % _crane.grab_cost
	_set_line("Roll the claw out over the junk, then hit Space. It sinks, it shuts, and everything it closed on is yours — one dig per visit.")
	_refresh()

# --- What came up --------------------------------------------------------------

## One piece out of the haul: a real part goes in the spare-parts stash, plain
## junk gets weighed in as scrap. Tally it up rather than announcing it — a
## basketful is one event to the player, not five.
func _on_dug(item: Node2D, part: PartData, scrap: int) -> void:
	if part != null:
		Inventory.add_part(part)
		_haul.append(part.display_name)
	else:
		Inventory.add_scrap(scrap)
		_haul_scrap += scrap
	_refresh()

## The claw is back at the trolley: say what it came up with, show it over the
## heap, then head back to the yard. A visit to the pen is one dig.
##
## The crane is shut off for the duration — a Space press in the last moment
## before the scene changes shouldn't start a second dig nobody paid for.
func _on_dig_finished(caught: int) -> void:
	_crane.controls_enabled = false
	var summary := _summarise(caught)
	_set_line(summary)
	if caught > 0:
		_popup(summary, POPUP_AT)
	_refresh()
	_haul.clear()
	_haul_scrap = 0
	if exit_delay > 0.0:
		await get_tree().create_timer(exit_delay).timeout
	if not is_inside_tree():
		return
	if exit_scene.is_empty():
		# Staying put (see `exit_scene`): hand the controls back so another dig
		# can be lined up. This is the mode the smoke test runs in.
		_crane.controls_enabled = true
		return
	_leave()

func _on_missed() -> void:
	if _heap.is_empty():
		_set_line("The heap's picked clean - there's nothing left down there to grab.")
	else:
		_set_line("The jaws come up on bare floor. Nothing under the claw that time - and nothing charged for it.")
	_refresh()

func _on_denied() -> void:
	_set_line("A dig costs $%d and you're carrying $%d. The claw stays up there until you can pay."
			% [_crane.grab_cost, Inventory.money])
	_refresh()

## One line describing a haul: the parts by name, and the scrap if there was
## any. A miss has nothing to describe.
func _summarise(caught: int) -> String:
	if caught <= 0:
		return "Nothing came up that time."
	var bits: Array[String] = []
	if not _haul.is_empty():
		bits.append(", ".join(_haul))
	if _haul_scrap > 0:
		bits.append("%d scrap" % _haul_scrap)
	return "Up comes %s." % " and ".join(bits)

## Hand the player back to the yard with the haul saved.
func _leave() -> void:
	if exit_scene.is_empty():
		return
	SaveSystem.save_game()
	get_tree().change_scene_to_file(exit_scene)

# --- HUD -----------------------------------------------------------------------

func _refresh() -> void:
	_money.text = "$%d        %d pieces left" % [Inventory.money, _heap.count()]

func _set_line(text: String) -> void:
	_line.text = text

## Floating "what came up" banner over the pit, same drift-and-fade the trash
## props use. World space, not screen space: it belongs over the heap, not over
## the HUD. Wrapped and centred, because a basketful of four parts is a long
## sentence and the font is big.
func _popup(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", POPUP_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 7)
	# Bigger than a yard popup: the pen's camera is zoomed out to fit the crane,
	# so world-space text arrives on screen smaller than it was authored.
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(POPUP_WIDTH, 0.0)
	label.z_index = 10
	add_child(label)
	label.position = Vector2(at.x - POPUP_WIDTH * 0.5, at.y)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - POPUP_RISE, POPUP_LIFETIME)
	tween.parallel().tween_property(label, "modulate:a", 0.0, POPUP_LIFETIME)
	tween.tween_callback(label.queue_free)

# --- Drawing -------------------------------------------------------------------

## Painted behind everything: a drab sky, the yard wall the yard is fenced with,
## the ground, and the pit the junk gets tipped into. It's the pen's root on
## purpose — a node draws before its children, so this all lands behind the
## Y-sorted `Yard` with the crane and the heap in it.
func _draw() -> void:
	var view := Rect2(-2400.0, -1500.0, 4800.0, 3600.0)
	draw_rect(view, sky_color)
	draw_rect(Rect2(-2400.0, 0.0, 4800.0, 1200.0), dirt_color)
	_draw_wall()
	draw_rect(pit_rect, pit_color)
	draw_rect(pit_rect, kerb_color, false, 10.0)
	_draw_stains()

## Corrugated sheet along the back of the lot, ribs and all.
func _draw_wall() -> void:
	var top := -900.0
	var height := 250.0
	draw_rect(Rect2(-2400.0, top, 4800.0, height), wall_color)
	var x := -2400.0
	while x < 2400.0:
		draw_line(Vector2(x, top), Vector2(x, top + height), wall_dark, 6.0)
		x += 34.0
	draw_line(Vector2(-2400.0, top), Vector2(2400.0, top), wall_dark, 10.0)
	draw_line(Vector2(-2400.0, top + height), Vector2(2400.0, top + height), wall_dark, 10.0)

## Oil stains around the machinery, deterministic so the lot doesn't shimmer.
func _draw_stains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 12:
		var pos := Vector2(rng.randf_range(-900.0, 800.0), rng.randf_range(20.0, 320.0))
		draw_circle(pos, rng.randf_range(30.0, 74.0), stain_color)
