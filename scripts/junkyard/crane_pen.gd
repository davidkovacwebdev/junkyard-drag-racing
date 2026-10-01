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
## The garage's part row, shown for each part a dig brings up: its icon,
## name and stat bars, as the player will see it in the garage.
const PART_CARD := preload("res://scenes/garage/part_slot.tscn")
const CARD_WIDTH := 330.0
const CARD_SECONDS := 5.0
## Grandpa's "Gone Fishin'": the first dig meets its goal, and he gets told
## what it brought up (a part's name, or nothing for a miss or plain junk).
const FISH_QUEST := &"crane_fish"

@onready var _crane: CraneRig = $Yard/Crane
@onready var _heap: TrashHeap = $Yard/Heap
@onready var _money: Label = $UI/Money
@onready var _line: Label = $UI/Line
@onready var _hint: Label = $UI/Hint

## The pieces the current dig brought up: part names, and the scrap the plain
## junk weighed in as. Filled by `dug` as it fires once per piece, read out and
## cleared by `_on_dig_finished` — one dig, one summary.
var _haul: Array[String] = []
var _haul_parts: Array[PartData] = []
var _haul_scrap: int = 0
## The part cards from the last dig, popped up in the middle of the screen.
var _cards: VBoxContainer
var _cards_tween: Tween

func _ready() -> void:
	_crane.dug.connect(_on_dug)
	_crane.missed.connect(_on_missed)
	_crane.denied.connect(_on_denied)
	_crane.dig_finished.connect(_on_dig_finished)
	_hint.text = "A / D  roll the claw over the heap     Space  drop the claw ($%d a go), Space again to shut it     Esc  leave" % _crane.grab_cost
	_set_line("Roll the claw out over the junk and hit Space to drop it. Hit Space again to shut it - whatever it's holding is yours. $%d a go, as long as your money lasts."
			% _crane.grab_cost)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_cards)
	_refresh()

# --- What came up --------------------------------------------------------------

## One piece out of the haul: a real part goes in the spare-parts stash, plain
## junk gets weighed in as scrap. Tally it up rather than announcing it — a
## basketful is one event to the player, not five.
func _on_dug(item: Node2D, part: PartData, scrap: int) -> void:
	if part != null:
		Inventory.add_part(part)
		_haul.append(part.display_name)
		_haul_parts.append(part)
	else:
		Inventory.add_scrap(scrap)
		_haul_scrap += scrap
	_refresh()

## The claw is back at the trolley: say what it came up with and show it over
## the heap. The player stays in the pen — the crane is ready for another go
## straight away, and they leave with Back / Esc when they're done.
##
## Saved after every dig, catch or miss: the money is already spent, and a
## player who quits from the pen shouldn't lose the parts they paid for.
func _on_dig_finished(caught: int) -> void:
	if caught > 0:
		_set_line(_summarise(caught))
		_popup(_summarise(caught), POPUP_AT)
		Sfx.play(&"part_pickup" if not _haul.is_empty() else &"scrap_pickup", -4.0, 0.0)
	if not _haul_parts.is_empty():
		_show_cards(_haul_parts)
	if Quests.has_quest(FISH_QUEST) and not Quests.is_ready(FISH_QUEST):
		Quests.set_note(FISH_QUEST, _haul_parts[0].display_name if not _haul_parts.is_empty() else "")
		Quests.goal_met(FISH_QUEST)
	_refresh()
	_haul.clear()
	_haul_parts.clear()
	_haul_scrap = 0
	SaveSystem.save_game()

func _on_missed() -> void:
	if _heap.is_empty():
		_set_line("The heap's picked clean - there's nothing left down there to grab.")
	else:
		_set_line("The jaws come up empty. That's $%d down - line it up and try again." % _crane.grab_cost)
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

# --- HUD -----------------------------------------------------------------------

func _refresh() -> void:
	_money.text = "$%d        %d pieces left" % [Inventory.money, _heap.count()]

## One garage-style card per part in `parts`, replacing the last dig's,
## popped up in the middle of the screen and gone again after a few seconds.
func _show_cards(parts: Array[PartData]) -> void:
	if _cards_tween != null:
		_cards_tween.kill()
	for child in _cards.get_children():
		child.queue_free()
	for part in parts:
		var card: PartSlot = PART_CARD.instantiate()
		card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
		# Just for looking at: nothing to drag it onto here.
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.category = part.category
		_cards.add_child(card)
		card.set_part(part)
	_cards.modulate.a = 0.0
	# Fit to the new cards and centre them on screen; the pop grows from
	# their middle.
	_cards.reset_size()
	var card_size := _cards.get_combined_minimum_size()
	_cards.size = card_size
	_cards.position = (get_viewport().get_visible_rect().size - card_size) * 0.5
	_cards.pivot_offset = card_size * 0.5
	_cards.scale = Vector2(0.6, 0.6)
	_cards_tween = create_tween()
	_cards_tween.tween_property(_cards, "modulate:a", 1.0, 0.15)
	_cards_tween.parallel().tween_property(_cards, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cards_tween.tween_interval(CARD_SECONDS)
	_cards_tween.tween_property(_cards, "modulate:a", 0.0, 0.4)

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
	draw_rect(Rect2(pit_rect.position, Vector2(pit_rect.size.x, 14.0)), kerb_color)
	_draw_stains()

## Sheet-metal wall along the back of the lot, a few wide ribs.
func _draw_wall() -> void:
	var top := -900.0
	var height := 250.0
	draw_rect(Rect2(-2400.0, top, 4800.0, height), wall_color)
	var x := -2400.0
	while x < 2400.0:
		draw_rect(Rect2(x, top, 18.0, height), wall_dark)
		x += 160.0

## Oil stains around the machinery, deterministic so the lot doesn't shimmer.
func _draw_stains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 6:
		var pos := Vector2(rng.randf_range(-900.0, 800.0), rng.randf_range(20.0, 320.0))
		var radius := rng.randf_range(40.0, 80.0)
		draw_colored_polygon(FlatProps.octagon(pos, radius, radius * 0.6), stain_color)
