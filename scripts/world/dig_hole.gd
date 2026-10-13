class_name DigHole
extends Node2D
## A hole the digger's scooped in the ground ("Dig It"): each scoop at the
## same spot takes it a stage deeper, up to a proper hole at `FULL`, with
## its dirt piled up beside it. The one over the treasure ends up with the
## chest showing in it (`reveal_chest()`).

const GROUP := &"dig_hole"
const FULL := 3
## A scoop this close to an existing hole digs that one deeper.
const SAME_HOLE := 60.0
const HOLE := Color(0.16, 0.12, 0.09, 1)
const HOLE_RIM := Color(0.3, 0.23, 0.16, 1)
const DIRT := Color(0.42, 0.32, 0.22, 1)
const DIRT_SHADE := Color(0.35, 0.26, 0.18, 1)
const CHEST := Color(0.5, 0.32, 0.17, 1)
const CHEST_LID := Color(0.4, 0.25, 0.13, 1)
const LATCH := Color(0.9, 0.72, 0.2, 1)
## Hole size per stage (radius across; it's squashed for the ground).
const RADIUS := [0.0, 16.0, 26.0, 36.0]

var stage := 0
var has_chest := false
var _chest_pop := 1.0

## Digs at `point`: one stage deeper on the hole already there, or a new one.
## Returns the hole.
static func scoop(sortables: Node, point: Vector2) -> DigHole:
	var hole: DigHole = null
	for node in sortables.get_tree().get_nodes_in_group(GROUP):
		var other := node as DigHole
		if other.global_position.distance_to(point) <= SAME_HOLE:
			hole = other
	if hole == null:
		hole = DigHole.new()
		hole.position = point
		sortables.add_child(hole)
	hole.stage = mini(hole.stage + 1, FULL)
	hole.queue_redraw()
	return hole

## A finished hole at `spot`, with the chest still in it or not (reloading
## after it was found).
static func place_found(sortables: Node, spot: Vector2, chest: bool) -> DigHole:
	if sortables == null:
		return null
	var hole := DigHole.new()
	hole.position = spot
	hole.stage = FULL
	hole.has_chest = chest
	sortables.add_child(hole)
	return hole

func _ready() -> void:
	add_to_group(GROUP)
	z_index = -1

func is_full() -> bool:
	return stage >= FULL

## The chest's lid shows in the hole, with a little pop.
func reveal_chest() -> void:
	has_chest = true
	_chest_pop = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void:
		_chest_pop = t
		queue_redraw(), 0.0, 1.0, 0.5)

func _draw() -> void:
	var r: float = RADIUS[stage]
	# The dirt heaped up behind the hole.
	draw_colored_polygon(FlatProps.octagon(Vector2(r * 0.9, -r * 0.35), r * 0.75, r * 0.45), DIRT)
	draw_colored_polygon(FlatProps.octagon(Vector2(r * 1.1, -r * 0.25), r * 0.45, r * 0.3), DIRT_SHADE)
	draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, r + 4.0, (r + 4.0) * 0.45), HOLE_RIM)
	draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, r, r * 0.45), HOLE)
	if not has_chest:
		return
	var lift := 10.0 * _chest_pop
	var top := Vector2(0.0, 2.0 - lift)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-20.0, -8.0), top + Vector2(20.0, -8.0),
			top + Vector2(20.0, 8.0), top + Vector2(-20.0, 8.0)]), CHEST)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-21.0, -14.0), top + Vector2(21.0, -14.0),
			top + Vector2(20.0, -6.0), top + Vector2(-20.0, -6.0)]), CHEST_LID)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-4.0, -9.0), top + Vector2(4.0, -9.0),
			top + Vector2(4.0, 1.0), top + Vector2(-4.0, 1.0)]), LATCH)
