@tool
class_name TrashProp
extends StaticBody2D
## Roadside trash you can open: a big `CONTAINER` (open-top dumpster) or a small
## `BIN`, each drawn as flat polygon art in two states — full and empty.
##
## Full props are interactable. PlayerCar finds any body with a non-empty
## `display_name` (duck-typed, same as `Obstacle`) and, when it also has an
## `interact()` method, calls that instead of switching scene. Emptying a prop
## blanks its `display_name` too, so a spent bin is just scenery you drive past.
##
## Opening a bin banks nothing by itself: it tips a handful of `Pickup` orbs out
## onto the shoulder — mostly scrap, rarely a real car part — and those are what
## the player drives over and collects. That's why the "+N scrap" text lives on
## the orb and not here: nothing is yours until you've actually run over it.
##
## Whether a prop is full outlives the map. The spawner gives each one a
## `loot_id`, and WorldState remembers which are empty and refills every one of
## them in a single pass each morning (sometime between 8 and 9 AM) — the city
## starts mostly picked-over, so a full bin is worth a detour. See
## WorldState.is_prop_full() and WorldState.restocked.
##
## **Art space**: origin at the prop's ground contact point, everything drawn
## above it (negative Y). That's deliberate and is what makes the Y-sort against
## the car come out right — a prop's base is its sort position, exactly like the
## car's own origin. It's also why this does *not* extend `Obstacle`, which
## centres its art on the origin instead.

## Emitted once per emptying, carrying the total scrap value of the orbs that
## came out. Parts aren't counted — they go to the spare-parts stash instead.
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
## How rounded the collision footprint's corners are — see RoundedRectShape.
## Keeps the car from catching and stopping dead on a sharp corner; it slides
## past instead.
@export_range(0.0, 20.0) var corner_radius: float = 6.0

@export_group("Colors")
@export var body_color: Color = Color(0.34, 0.42, 0.4, 1)
@export var lid_color: Color = Color(0.29, 0.35, 0.34, 1)
@export var trim_color: Color = Color(0.58, 0.6, 0.55, 1)
## Inside of the box, visible once the lid swings open.
@export var interior_color: Color = Color(0.13, 0.15, 0.15, 1)
@export var trash_color: Color = Color(0.26, 0.24, 0.21, 1)
@export var rust_color: Color = Color(0.55, 0.32, 0.18, 0.75)
@export var shadow_color: Color = Color(0, 0, 0, 0.16)

@export_group("Drops")
## How many scrap orbs come out, and what each one is worth. The spread is what
## makes one bin feel luckier than the next, so the totals overlap a lot.
@export var scrap_drops_min: int = 2
@export var scrap_drops_max: int = 4
@export var scrap_per_drop_min: int = 1
@export var scrap_per_drop_max: int = 3
## Chance the haul is hiding a real car part at all. Deliberately low: a part is
## the reason to keep opening bins, not the usual outcome.
@export_range(0.0, 1.0) var part_chance: float = 0.14
## Extra part chance a CONTAINER gets on top of `part_chance`. A dumpster is a
## better bet than a street bin, and it's a reason to bother with the big ones.
@export_range(0.0, 1.0) var container_part_bonus: float = 0.08
## Which kind of part turns up when one does. Wheels are common, engines rare —
## the three shares should add up to 1.
@export_range(0.0, 1.0) var wheel_share: float = 0.62
@export_range(0.0, 1.0) var body_share: float = 0.26
## How far apart orbs land on the same side of the bin, the apex of their arc,
## and how long the toss takes. Short and low: this is junk tumbling out, not a
## display.
@export var drop_gap: float = 52.0
@export var drop_arc: float = 42.0
@export var drop_flight_time: float = 0.42

@export_group("Sources")
@export var scrap_pickup_scene: PackedScene = preload("res://scenes/world/scrap_pickup.tscn")
@export var part_pickup_scene: PackedScene = preload("res://scenes/world/part_pickup.tscn")

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

## The lid is hinged along the back of the rim and flipped up behind the box.
## How tall it stands above the rim, as a share of the top width. Full boxes
## get a lid that is leaned further back by the heap, so it shows less.
const LID_OPEN_RISE := 0.42
## A full container's lid lies shut on top, propped up at the front by the
## heap: this is the gap between the rim and the lid's front lip, in pixels.
const LID_PROP_GAP := 12.0
const LID_THICKNESS := 16.0
## Chance a full small bin has a bag dumped beside it. Full containers always do.
const BIN_OVERFLOW_CHANCE := 0.4
## How deep the open top looks (front rim to back rim), as a share of the top width.
const OPENING_DEPTH := 0.14
## Small bins keep a side-hinged lid instead. Lid angle when the bin still has
## trash in it: closed, but eased up a crack by the junk heaped against it.
const BIN_LID_FULL_ANGLE := -0.10
## Lid angle once emptied. Negative swings the free edge up and back (Godot 2D
## rotation is clockwise for positive angles), opening the bin to view.
const BIN_LID_OPEN_ANGLE := -1.15

const TRASH_NOUNS := [
	"bent hubcap", "rusty can", "cracked mirror", "wire bundle",
	"chewed tire", "broken tail light", "spring scrap", "soggy cardboard",
	"faded license plate", "crunched bumper", "melted bottle", "loose bolts",
]

## Name authored on the scene, kept aside so it can be restored if the prop is
## ever refilled. `_apply_state()` blanks `display_name` while empty.
var _prompt_name: String = ""

## Ground footprint of a kind, so a spawner can keep a prop's base clear of the
## tarmac without instantiating anything.
static func footprint_for(target: Kind) -> Vector2:
	return CONTAINER_FOOTPRINT if target == Kind.CONTAINER else BIN_FOOTPRINT

func _ready() -> void:
	_prompt_name = display_name
	if Engine.is_editor_hint():
		# Editor preview: draw the prop in whatever state is authored on the
		# scene. WorldState isn't reachable from the editor, and nothing below
		# runs, so merely opening the scene can't rewrite it.
		queue_redraw()
		return
	# WorldState owns the answer to "is there anything in this one?" — it's the
	# only thing that knows which props are empty and which have restocked.
	filled = WorldState.is_prop_full(loot_id)
	_apply_state()
	WorldState.restocked.connect(_on_world_restocked)

## The morning restock just refilled the whole city — pick up the change
## immediately instead of waiting for the next map reload, so a prop the
## player emptied yesterday visibly reopens while they're still driving
## around today.
func _on_world_restocked() -> void:
	if not filled:
		filled = WorldState.is_prop_full(loot_id)

## Size the collision to this kind's footprint and decide whether the prop is
## still worth offering to the player.
##
## Editor mode only redraws: the derived collision and the blanked
## `display_name` are runtime state, so writing them while editing would save
## that state into the scene (and blanking a hand-placed prop's name would be
## permanent, since `_prompt_name` is captured from it on load).
func _apply_state() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	display_name = _prompt_name if filled else ""
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		var footprint := footprint_for(kind)
		shape.shape = RoundedRectShape.build(footprint, corner_radius)
		shape.position = Vector2(0.0, -footprint.y * 0.5)
	queue_redraw()

## Redraw when an exported property is changed in the editor, so swapping a bin
## for a dumpster or editing one of the Colors updates the viewport straight
## away instead of waiting for the next reload. `filled` has its own setter and
## never gets here. Always returns false, i.e. "not handled", so Godot still
## assigns the property itself — this only ever adds a redraw, never a state
## change, and the guard keeps it out of the runtime path entirely.
func _set(_property: StringName, _value: Variant) -> bool:
	if Engine.is_editor_hint():
		queue_redraw()
	return false

# --- Interaction ---------------------------------------------------------------

## Verb PlayerCar drops into its prompt ("Hold E to loot"). Duck-typed —
## see PlayerCar._process_interaction().
func get_interact_verb() -> String:
	return "loot"

## Seconds PlayerCar requires E to be held before looting fires — long
## enough that a drive-by tap doesn't loot it by accident. Duck-typed, same as
## get_interact_verb(); a target with no such method activates instantly.
func get_interact_hold_duration() -> float:
	return 0.2

## Called by PlayerCar on E. Kept separate from `loot()` so a future prop
## could interact differently without changing the car.
func interact(_actor: Node = null) -> void:
	loot()

## Empty this prop out onto the ground. Returns the total scrap value of the orbs
## that came out, or 0 if it was already empty.
##
## Nothing is banked here on purpose — the orbs are what the player has to drive
## over (see `Pickup`). Emitting the total is only so a caller can react to the
## haul (sound, score) without walking the dropped orbs.
func loot() -> int:
	if not filled:
		return 0
	var rng := _rng()
	var scrap := _spill_scrap(rng)
	var hit_part := rng.randf() < part_chance \
			+ (container_part_bonus if kind == Kind.CONTAINER else 0.0)
	if hit_part:
		_spill_part(rng)

	filled = false
	Sfx.play_at(&"trash_rummage", global_position, -4.0)
	if loot_id != "":
		WorldState.mark_emptied(loot_id)
	looted.emit(scrap)
	return scrap

# --- Spilling the loot ---------------------------------------------------------

## Tip a handful of scrap orbs out of the bin and onto the shoulder. Returns what
## they add up to in total.
func _spill_scrap(rng: RandomNumberGenerator) -> int:
	if scrap_pickup_scene == null:
		return 0
	var count := rng.randi_range(
			maxi(scrap_drops_min, 1), maxi(scrap_drops_max, scrap_drops_min))
	var total := 0
	for i in count:
		var orb := scrap_pickup_scene.instantiate() as ScrapPickup
		if orb == null:
			break
		var amount := rng.randi_range(maxi(scrap_per_drop_min, 1),
				maxi(scrap_per_drop_max, scrap_per_drop_min))
		orb.amount = amount
		total += amount
		# Name some of the scrap after a real piece of junk. Often enough to make
		# the popups feel written, rare enough that they don't all read the same.
		if rng.randf() < 0.35:
			orb.noun = String(TRASH_NOUNS[rng.randi_range(0, TRASH_NOUNS.size() - 1)])
		# Side alternates so a handful fans out across the road rather than piling
		# up on one side of the bin; `i / 2` is how many already went that way, so
		# each one lands a step further out than the last on its own side.
		_launch_orb(orb, rng, 0.07 * float(i),
				-1.0 if i % 2 == 0 else 1.0, i / 2)
	return total

## The rare good find: one real car part, in an orb of its own. Weighted towards
## wheels, because that's the part a junk car wants most of and the one that
## reads as a win without trivialising the hunt for a body or an engine.
func _spill_part(rng: RandomNumberGenerator) -> void:
	if part_pickup_scene == null:
		return
	var pool := _pick_part_pool(rng)
	if pool.is_empty():
		return
	var orb := part_pickup_scene.instantiate() as PartPickup
	if orb == null:
		return
	orb.configure(pool[rng.randi_range(0, pool.size() - 1)])
	# A beat after the scrap so the part orb reads as the last, special thing out
	# of the bin instead of just another orb in the burst, and one rank further
	# out so it can never share a spot with a scrap orb.
	_launch_orb(orb, rng, 0.34, 1.0 if rng.randf() < 0.5 else -1.0, 2)

## Which part list to draw from, weighted by the export shares. Falls through the
## other two lists when the chosen one is empty, so a part still drops even if
## its category has nothing in the database yet.
func _pick_part_pool(rng: RandomNumberGenerator) -> Array:
	var roll := rng.randf()
	if roll < wheel_share:
		return _first_filled([PartDatabase.wheels, PartDatabase.bodies, PartDatabase.junk_engines])
	if roll < wheel_share + body_share:
		return _first_filled([PartDatabase.bodies, PartDatabase.junk_engines, PartDatabase.wheels])
	return _first_filled([PartDatabase.junk_engines, PartDatabase.wheels, PartDatabase.bodies])

static func _first_filled(pools: Array) -> Array:
	for pool in pools:
		if pool is Array and not (pool as Array).is_empty():
			return pool
	return []

## Throw one orb out of the bin's mouth and let it land on the road beside it.
##
## Two things matter here. The orb is parented to whatever holds the prop — the
## Y-sorted layer — so it sorts against the car the same way the prop does, and
## so it outlives the prop scene. And the landing spot is pushed at least clear
## of the prop's own footprint: a car can't drive through the bin, so an orb that
## landed underneath it would be unreachable.
##
## `side` is -1 or +1, and `rank` counts how many orbs have already gone to that
## side. Orbs are put in fixed slots along the roadside, one `drop_gap` apart per
## rank, rather than each getting its own random distance. Two orbs landing
## within a collect radius of each other merge into one blob and get collected in
## the same instant, which reads as the bin having dropped less than it did — a
## line of separate orbs reads as a bin's worth of loot.
func _launch_orb(orb: Pickup, rng: RandomNumberGenerator, delay: float,
		side: float, rank: int) -> void:
	var parent := get_parent()
	if parent == null:
		orb.queue_free()
		return
	# The slot step never goes below the collect radius plus a margin, so a
	# tuned-down `drop_gap` still can't let two orbs share a pickup.
	var step := maxf(drop_gap, Pickup.COLLECT_RADIUS + 8.0)
	var clear_of_prop := footprint_for(kind).x * 0.5 + Pickup.COLLECT_RADIUS + 8.0
	var reach := clear_of_prop + float(rank) * step + rng.randf_range(0.0, 4.0)
	var landing := global_position + Vector2(
			side * reach, rng.randf_range(-5.0, 5.0))
	parent.add_child(orb)
	orb.launch(_mouth_global(), landing, drop_arc, drop_flight_time, delay)

## World position of the bin's mouth — the rim the orbs tumble over. Drawing them
## out of here rather than off the ground is what sells the "tipped out" read.
func _mouth_global() -> Vector2:
	return global_position + Vector2(0.0, -_height() + _lid_height() * 0.5)

# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	# One generator threaded through the whole prop, so the trash arrangement and
	# the rust patches are laid out in a consistent, repeatable order.
	var rng := _rng()
	var bottom := _width_bottom()
	var top := _width_top()
	var height := _height()

	# Contact shadow, so the prop doesn't look like it's hovering.
	draw_colored_polygon(_ellipse(Vector2(0.0, -2.0), bottom * 0.62, 8.0), shadow_color)
	if kind == Kind.CONTAINER and filled:
		_draw_interior(top, height)
		_draw_trash(top, height, rng)
		_draw_body(bottom, top, height, rng)
		_draw_closed_lid(top, height)
	elif kind == Kind.CONTAINER:
		_draw_lid(top, height)
		_draw_interior(top, height)
		_draw_body(bottom, top, height, rng)
	else:
		_draw_body(bottom, top, height, rng)
		_draw_bin_interior(top, height)
		_draw_bin_lid(top, height)
		if filled:
			_draw_bin_trash(top, height, rng)
	_draw_base(bottom)
	if filled:
		_draw_overflow(bottom, height)

## The tapered steel box, plus a shaded side face, ribs and rust patches. Every
## shape here is a flat fill — no outline strokes, matching the house/tree art.
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

	# Shaded side face, so the box reads as a solid volume instead of a flat
	# outline drawing — the same trick the tree trunks use for their `Shade`
	# panel.
	var shade_share := 0.3
	draw_colored_polygon(PackedVector2Array([
		Vector2(bottom * 0.5 - bottom * shade_share, 0.0),
		Vector2(bottom * 0.5, 0.0),
		Vector2(top * 0.5, -height),
		Vector2(top * 0.5 - top * shade_share, -height),
	]), body_color.darkened(0.18))

	if kind == Kind.CONTAINER:
		var center := Vector2(
			rng.randf_range(-bottom * 0.3, bottom * 0.3),
			rng.randf_range(-height * 0.7, -height * 0.3))
		draw_colored_polygon(_blob(center, bottom * 0.26, height * 0.26, rng), rust_color)

## The open top, seen from slightly above: a dark quad between the front rim
## and the back rim. The trash in a full box sits in here.
func _draw_interior(top: float, height: float) -> void:
	var back := _back_rim(top, height)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-top * 0.5, -height), Vector2(top * 0.5, -height),
		Vector2(back.x, back.y), Vector2(-back.x, back.y),
	]), interior_color)

## Right-hand end of the back rim, where the lid's hinge runs.
func _back_rim(top: float, height: float) -> Vector2:
	return Vector2(top * 0.5 - top * 0.05, -height - top * OPENING_DEPTH)

## The lid, flipped up on its back hinge so it stands behind the box: we see
## its underside, a shade darker, with the grab handle along its top edge.
func _draw_lid(top: float, height: float) -> void:
	var overhang := 8.0 if kind == Kind.CONTAINER else 4.0
	var hinge := _back_rim(top, height)
	var half := hinge.x + overhang
	var rise := top * LID_OPEN_RISE
	var lean := top * 0.06
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half, hinge.y),
		Vector2(half, hinge.y),
		Vector2(half - lean, hinge.y - rise),
		Vector2(-half + lean, hinge.y - rise),
	]), lid_color.darkened(0.12))
	draw_rect(Rect2(-13.0, hinge.y - rise - 5.0, 26.0, 6.0), trim_color)

## The lid shut over the top and propped up a crack by the heap, so the bags
## show between the rim and the lid's front lip.
func _draw_closed_lid(top: float, height: float) -> void:
	var half := top * 0.5 + 8.0
	var lip_bottom := -height - LID_PROP_GAP
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half, lip_bottom),
		Vector2(half, lip_bottom),
		Vector2(half - 4.0, lip_bottom - LID_THICKNESS),
		Vector2(-half + 4.0, lip_bottom - LID_THICKNESS),
	]), lid_color)
	draw_rect(Rect2(-13.0, lip_bottom - LID_THICKNESS - 5.0, 26.0, 6.0), trim_color)

## Bags crammed into the box, their tops squeezing out under the propped lid.
## The body and lid are drawn over them, so only the middle band shows.
func _draw_trash(top: float, height: float, rng: RandomNumberGenerator) -> void:
	var bags := 3
	var bag_size := Vector2(top * 0.4, height * 0.34)
	for i in bags:
		var center := Vector2(
			lerpf(-top * 0.28, top * 0.28, float(i) / float(bags - 1)),
			-height - LID_PROP_GAP * 0.5 + rng.randf_range(-2.0, 2.0))
		draw_colored_polygon(_blob(center, bag_size.x, bag_size.y, rng),
				trash_color.lightened(0.08 * float(i % 2)))

## The bin's shaded inside, seen through its front. Drawn before the lid, so a
## closed (full) lid hides it and an open (empty) lid leaves it visible.
func _draw_bin_interior(top: float, height: float) -> void:
	var inset := top * 0.07
	var depth := height * 0.4
	var half := top * 0.5 - inset
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half, -height + inset * 0.6),
		Vector2(half, -height + inset * 0.6),
		Vector2(half * 0.86, -height + depth),
		Vector2(-half * 0.86, -height + depth),
	]), interior_color)

## The bin's lid, hinged at its left edge and rotated as a unit: nearly shut
## while there's trash holding it up, swung right back once the bin is empty.
func _draw_bin_lid(top: float, height: float) -> void:
	var lid_h := _lid_height()
	var lid_w := top + 8.0
	draw_set_transform(Vector2(-lid_w * 0.5, -height), BIN_LID_FULL_ANGLE if filled else BIN_LID_OPEN_ANGLE, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(lid_w, -lid_h * 0.18),
		Vector2(lid_w, -lid_h),
		Vector2(0.0, -lid_h * 0.82),
	]), lid_color)
	draw_rect(Rect2(lid_w * 0.5 - 13.0, -lid_h - 6.0, 26.0, 6.0), trim_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Trash heaped over the bin's rim and squeezing out from under the lid.
func _draw_bin_trash(top: float, height: float, rng: RandomNumberGenerator) -> void:
	var lid_h := _lid_height()
	for i in 2:
		var center := Vector2(lerpf(-top * 0.3, top * 0.5, float(i)),
			-height - lid_h * 0.5 - rng.randf_range(height * 0.04, height * 0.14))
		draw_colored_polygon(_blob(center, top * 0.34, height * 0.32, rng),
				trash_color.lightened(0.08 * float(i % 2)))

## Bags dumped on the ground beside a full box: always next to a container,
## sometimes next to a bin. Uses its own generator so it doesn't reshuffle the
## rest of the prop's art.
func _draw_overflow(bottom: float, height: float) -> void:
	var rng := _rng()
	rng.seed += 911
	var bags := 0
	if kind == Kind.CONTAINER:
		bags = rng.randi_range(1, 2)
	elif rng.randf() < BIN_OVERFLOW_CHANCE:
		bags = 1
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var bag_size := Vector2(height * 0.55, height * 0.42)
	for i in bags:
		var center := Vector2(side * (bottom * 0.5 + bag_size.x * (0.15 + 0.75 * i)), -bag_size.y * 0.42 + 8.0 * i)
		draw_colored_polygon(_ellipse(center + Vector2(4.0, bag_size.y * 0.45), bag_size.x * 0.55, 5.0), shadow_color)
		draw_colored_polygon(_blob(center, bag_size.x, bag_size.y, rng), trash_color.lightened(0.08 * float(i % 2)))

## Darker skirt and, on the container, the wheels it's meant to roll on.
func _draw_base(bottom: float) -> void:
	var band := 9.0 if kind == Kind.CONTAINER else 5.0
	draw_rect(Rect2(-bottom * 0.5, -band, bottom, band), body_color.darkened(0.26))
	if kind == Kind.CONTAINER:
		for side: float in [-1.0, 1.0]:
			draw_colored_polygon(FlatProps.octagon(Vector2(side * bottom * 0.3, -6.0), 6.0, 6.0), body_color.darkened(0.5))

# --- Geometry helpers ----------------------------------------------------------

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed if variant_seed != 0 else hash(loot_id)
	return rng

## A squashed, slightly irregular lump, used for trash bags and rust blooms.
func _blob(center: Vector2, width: float, height: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 7
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
