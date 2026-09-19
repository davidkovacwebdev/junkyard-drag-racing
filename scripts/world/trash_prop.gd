class_name TrashProp
extends StaticBody2D
## Roadside trash you can loot: a big `CONTAINER` (open-top dumpster) or a small
## `BIN`, each drawn as flat polygon art in two states — full and empty.
##
## Full props are interactable. PlayerCar finds any body with a non-empty
## `display_name` (duck-typed, same as `Obstacle`) and, when it also has an
## `interact()` method, calls that instead of switching scene. Looting rolls the
## haul, empties the prop and — because an emptied prop also blanks its
## `display_name` — stops offering the prompt at all, so a looted bin is just
## scenery you can still drive past.
##
## Emptied props stay empty across map reloads: the spawner gives every prop a
## `loot_id`, and `_ready()` asks WorldState whether that id was already looted.
##
## **Art space**: origin at the prop's ground contact point, everything drawn
## above it (negative Y). That's deliberate and is what makes the Y-sort against
## the car come out right — a prop's base is its sort position, exactly like the
## car's own origin. It's also why this does *not* extend `Obstacle`, which
## centres its art on the origin instead.

signal looted(scrap: int)

enum Kind {
	CONTAINER, ## Big open-top dumpster. Wider at the top, on little wheels.
	BIN,       ## Small tapered street rubbish bin.
}

## Which of the two models to draw.
@export var kind: Kind = Kind.BIN

## Full props can be looted; empty ones are scenery. Looting sets this to false.
@export var filled: bool = true:
	set(value):
		filled = value
		queue_redraw()
		if is_node_ready():
			_apply_state()

## Read by PlayerCar's interaction check (duck-typed). Blanked while empty so
## the car stops offering to loot it — see `_apply_state()`.
@export var display_name: String = "Trash Bin"

## Stable identity for this prop, set by the spawner. Used to remember that this
## particular prop was looted, so it comes back empty on the next map load.
@export var loot_id: String = ""
## Seeds the small variations (trash arrangement, rust patches) so every prop
## doesn't come out looking identical. Set by the spawner; 0 falls back to
## `loot_id` so a hand-placed prop is still stable.
@export var variant_seed: int = 0

@export_group("Colors")
@export var body_color: Color = Color(0.34, 0.42, 0.4, 1)
@export var lid_color: Color = Color(0.29, 0.35, 0.34, 1)
@export var outline_color: Color = Color(0.14, 0.17, 0.16, 0.85)
@export var trim_color: Color = Color(0.58, 0.6, 0.55, 1)
## Inside of the box, visible once the lid swings open.
@export var interior_color: Color = Color(0.13, 0.15, 0.15, 1)
@export var trash_color: Color = Color(0.26, 0.24, 0.21, 1)
@export var can_color: Color = Color(0.62, 0.6, 0.5, 1)
@export var rust_color: Color = Color(0.55, 0.32, 0.18, 0.75)
@export var shadow_color: Color = Color(0, 0, 0, 0.16)

## Scrap range for a normal haul, and the rarer jackpot on top of it.
@export var scrap_min: int = 1
@export var scrap_max: int = 3
@export_range(0.0, 1.0) var bonus_chance: float = 0.18
@export var bonus_min: int = 4
@export var bonus_max: int = 9

# --- Geometry, in art space (origin = ground contact, art extends upward) -----

const CONTAINER_W_BOTTOM := 132.0
const CONTAINER_W_TOP := 152.0
const CONTAINER_H := 92.0
const CONTAINER_LID_H := 13.0
const CONTAINER_FOOTPRINT := Vector2(150.0, 22.0)

const BIN_W_BOTTOM := 46.0
const BIN_W_TOP := 58.0
const BIN_H := 66.0
const BIN_LID_H := 9.0
const BIN_FOOTPRINT := Vector2(56.0, 18.0)

## Lid angle when the prop still has trash in it: closed, but eased up a crack
## by the junk heaped against it.
const LID_FULL_ANGLE := -0.10
## Lid angle once emptied. Negative swings the free edge up and back (Godot 2D
## rotation is clockwise for positive angles), opening the box to view.
const LID_OPEN_ANGLE := -1.15

const POPUP_RISE := 46.0
const POPUP_LIFETIME := 1.1

const TRASH_NOUNS := [
	"bent hubcap", "rusty can", "cracked mirror", "wire bundle",
	"chewed tire", "broken tail light", "spring scrap", "soggy cardboard",
	"faded license plate", "crunched bumper", "melted bottle", "loose bolts",
]

## Name authored on the scene, kept aside so it can be restored if the prop is
## ever refilled. `_apply_state()` blanks `display_name` while empty.
var _prompt_name: String = ""
## Where the Popup label rests, captured from the scene so each kind can sit it
## at its own height.
var _popup_home: Vector2 = Vector2.ZERO

## Ground footprint of a kind, so a spawner can keep a prop's base clear of the
## tarmac without instantiating anything.
static func footprint_for(target: Kind) -> Vector2:
	return CONTAINER_FOOTPRINT if target == Kind.CONTAINER else BIN_FOOTPRINT

func _ready() -> void:
	_prompt_name = display_name
	var popup := get_node_or_null("Popup") as Label
	if popup != null:
		_popup_home = popup.position
	# Already emptied on a previous visit? Come back empty.
	if loot_id != "" and WorldState.is_looted(loot_id):
		filled = false
	_apply_state()

## Size the collision to this kind's footprint and decide whether the prop is
## still worth offering to the player.
func _apply_state() -> void:
	display_name = _prompt_name if filled else ""
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		var rect := shape.shape as RectangleShape2D
		if rect != null:
			var footprint := footprint_for(kind)
			rect.size = footprint
			shape.position = Vector2(0.0, -footprint.y * 0.5)
	queue_redraw()

# --- Interaction ---------------------------------------------------------------

## Verb PlayerCar drops into its prompt ("Press space to loot"). Duck-typed —
## see PlayerCar._process_interaction().
func get_interact_verb() -> String:
	return "loot"

## Called by PlayerCar on space. Kept separate from `loot()` so a future prop
## could interact differently without changing the car.
func interact(_actor: Node = null) -> void:
	loot()

## Take the trash out of this prop. Returns the scrap found, or 0 if it was
## already empty.
func loot() -> int:
	if not filled:
		return 0
	var rng := _rng()
	var scrap := rng.randi_range(scrap_min, maxi(scrap_max, scrap_min))
	if rng.randf() < bonus_chance:
		# Occasional good haul — the reason it's worth opening every bin.
		scrap += rng.randi_range(bonus_min, maxi(bonus_max, bonus_min))
	var noun: String = TRASH_NOUNS[rng.randi_range(0, TRASH_NOUNS.size() - 1)]

	Inventory.add_scrap(scrap)
	filled = false
	if loot_id != "":
		WorldState.mark_looted(loot_id)
	_show_popup("+%d scrap — %s" % [scrap, noun])
	looted.emit(scrap)
	return scrap

## Floating "+N scrap" text that drifts up and fades out over the prop.
func _show_popup(text: String) -> void:
	var popup := get_node_or_null("Popup") as Label
	if popup == null:
		return
	popup.text = text
	popup.visible = true
	popup.position = _popup_home
	popup.modulate.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position:y", _popup_home.y - POPUP_RISE, POPUP_LIFETIME)
	tween.parallel().tween_property(
			popup, "modulate:a", 0.0, POPUP_LIFETIME * 0.6).set_delay(POPUP_LIFETIME * 0.35)
	tween.tween_callback(func() -> void: popup.visible = false)

# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	# One generator threaded through the whole prop, so the trash arrangement and
	# the rust patches are laid out in a consistent, repeatable order.
	var rng := _rng()
	var bottom := _width_bottom()
	var top := _width_top()
	var height := _height()
	var lid_h := _lid_height()

	# Contact shadow, so the prop doesn't look like it's hovering.
	draw_colored_polygon(_ellipse(Vector2(0.0, -2.0), bottom * 0.62, 8.0), shadow_color)
	_draw_body(bottom, top, height, rng)
	_draw_interior(top, height)
	_draw_lid(top, height, lid_h)
	if filled:
		_draw_trash(top, height, lid_h, rng)
	_draw_base(bottom)

## The tapered steel box, plus ribs and rust patches.
func _draw_body(bottom: float, top: float, height: float, rng: RandomNumberGenerator) -> void:
	var body := PackedVector2Array([
		Vector2(-bottom * 0.5, 0.0),
		Vector2(bottom * 0.5, 0.0),
		Vector2(top * 0.5, -height),
		Vector2(-top * 0.5, -height),
	])
	draw_colored_polygon(body, body_color)

	# A lighter band along the sunlit top edge, then the rib detail.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-top * 0.5, -height),
		Vector2(top * 0.5, -height),
		Vector2(top * 0.5, -height + height * 0.16),
		Vector2(-top * 0.5, -height + height * 0.16),
	]), body_color.lightened(0.12))

	var ribs := 4 if kind == Kind.CONTAINER else 2
	for i in ribs:
		var t := (float(i) + 0.5) / float(ribs)
		var x := lerpf(-bottom * 0.5, bottom * 0.5, t)
		draw_line(Vector2(x, -5.0), Vector2(x * (top / bottom), -height + 5.0),
				body_color.darkened(0.24), 2.0)

	var patches := 2 if kind == Kind.CONTAINER else 1
	for i in patches:
		var center := Vector2(
			rng.randf_range(-bottom * 0.34, bottom * 0.34),
			rng.randf_range(-height * 0.78, -height * 0.25))
		draw_colored_polygon(_blob(center, bottom * 0.24, height * 0.24, rng), rust_color)

	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]),
			outline_color, 2.0)

## The shaded inside of the box. Drawn before the lid, so a closed (full) lid
## hides it and an open (empty) lid leaves it plainly visible.
func _draw_interior(top: float, height: float) -> void:
	var inset := top * 0.07
	var depth := height * 0.4
	var half := top * 0.5 - inset
	var inner := PackedVector2Array([
		Vector2(-half, -height + inset * 0.6),
		Vector2(half, -height + inset * 0.6),
		Vector2(half * 0.86, -height + depth),
		Vector2(-half * 0.86, -height + depth),
	])
	draw_colored_polygon(inner, interior_color)
	# A faint far wall, so it reads as a box with depth rather than a hole.
	draw_line(inner[0], inner[1], interior_color.lightened(0.22), 3.0)

## The lid, hinged at its left edge and rotated as a unit: nearly shut while
## there's trash holding it up, swung right back once the box is empty.
func _draw_lid(top: float, height: float, lid_h: float) -> void:
	var overhang := 8.0 if kind == Kind.CONTAINER else 4.0
	var lid_w := top + overhang * 2.0
	var angle := LID_FULL_ANGLE if filled else LID_OPEN_ANGLE

	draw_set_transform(Vector2(-lid_w * 0.5, -height), angle, Vector2.ONE)
	var lid := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(lid_w, -lid_h * 0.18),
		Vector2(lid_w, -lid_h),
		Vector2(0.0, -lid_h * 0.82),
	])
	draw_colored_polygon(lid, lid_color)
	draw_polyline(PackedVector2Array([lid[0], lid[1], lid[2], lid[3], lid[0]]),
			outline_color, 2.0)
	# Grab handle on top, and the hinge pin at this end.
	draw_rect(Rect2(lid_w * 0.5 - 13.0, -lid_h - 6.0, 26.0, 6.0), trim_color)
	draw_circle(Vector2(0.0, -lid_h * 0.4), 4.0, trim_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Trash heaped over the rim and squeezing out from under the lid.
func _draw_trash(top: float, height: float, lid_h: float, rng: RandomNumberGenerator) -> void:
	var rim := -height
	# Overflowing past the lid's free (right) edge, the way a full skip looks.
	var spill := top * 0.5 + (8.0 if kind == Kind.CONTAINER else 4.0)
	for i in 2:
		var center := Vector2(
			lerpf(top * 0.1, spill + 6.0, float(i) + rng.randf_range(0.1, 0.5)),
			rim - lid_h * 0.4 - rng.randf_range(0.0, 12.0))
		draw_colored_polygon(_blob(center, top * 0.26, height * 0.28, rng),
				trash_color.lightened(rng.randf_range(0.0, 0.12)))

	var bags := 3 if kind == Kind.CONTAINER else 2
	for i in bags:
		var center := Vector2(
			rng.randf_range(-top * 0.34, top * 0.34),
			rim - lid_h * 0.5 - rng.randf_range(height * 0.06, height * 0.16))
		draw_colored_polygon(_blob(center, top * 0.3, height * 0.3, rng),
				trash_color.lightened(rng.randf_range(0.0, 0.1)))

	# A couple of small bits — cans and sticks — poking out of the heap.
	for i in 2:
		var center := Vector2(
			rng.randf_range(-top * 0.4, top * 0.4),
			rim - lid_h - rng.randf_range(2.0, 12.0))
		var size := Vector2(rng.randf_range(9.0, 15.0), rng.randf_range(5.0, 8.0))
		draw_colored_polygon(_rotated_quad(center, size, rng.randf_range(-1.3, 1.3)),
				can_color)

## Darker skirt and, on the container, the wheels it's meant to roll on.
func _draw_base(bottom: float) -> void:
	var band := 9.0 if kind == Kind.CONTAINER else 5.0
	draw_rect(Rect2(-bottom * 0.5, -band, bottom, band), body_color.darkened(0.26))
	if kind == Kind.CONTAINER:
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(side * bottom * 0.3, -6.0), 5.5, body_color.darkened(0.5))

# --- Geometry helpers ----------------------------------------------------------

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed if variant_seed != 0 else hash(loot_id)
	return rng

## A squashed, slightly irregular lump, used for trash bags and rust blooms.
func _blob(center: Vector2, width: float, height: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 9
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		var rx := width * 0.5 * (1.0 + rng.randf_range(-0.13, 0.13))
		var ry := height * 0.5 * (1.0 + rng.randf_range(-0.13, 0.13))
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _rotated_quad(center: Vector2, size: Vector2, angle: float) -> PackedVector2Array:
	var half := size * 0.5
	var points := PackedVector2Array()
	var corners := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	for corner in corners:
		points.append(center + corner.rotated(angle))
	return points

func _ellipse(center: Vector2, rx: float, ry: float, steps: int = 18) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _width_bottom() -> float:
	return CONTAINER_W_BOTTOM if kind == Kind.CONTAINER else BIN_W_BOTTOM

func _width_top() -> float:
	return CONTAINER_W_TOP if kind == Kind.CONTAINER else BIN_W_TOP

func _height() -> float:
	return CONTAINER_H if kind == Kind.CONTAINER else BIN_H

func _lid_height() -> float:
	return CONTAINER_LID_H if kind == Kind.CONTAINER else BIN_LID_H
