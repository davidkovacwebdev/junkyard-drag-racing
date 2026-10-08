@tool
class_name OldWindmill
extends StaticBody2D
## A lone wooden tower windmill out in the plains, next to the homestead. Its
## four big sails turn slowly and the axle creaks (`windmill_creak`, via an
## AmbientCall in the scene). Origin on the ground under the tower so it
## Y-sorts against the car.

const WALL := Color(0.79, 0.71, 0.56)
const CAP := Color(0.42, 0.3, 0.2)
const DOOR := Color(0.35, 0.24, 0.15)
const SAIL := Color(0.9, 0.86, 0.76)
const HUB := UiPalette.METAL_GREY

const HUB_POSITION := Vector2(4.0, -268.0)
const SAIL_LENGTH := 150.0
const SAIL_WIDTH := 40.0
const SPIN_SPEED := 0.45

var _sail_angle := 0.3

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(130.0, 28.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -14.0)
	add_child(collision)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_sail_angle = wrapf(_sail_angle + SPIN_SPEED * delta, 0.0, TAU)
	queue_redraw()

## Tower (tapering, shade strip on the right), dark cap, door, then the four
## sails and the hub on top.
func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(10.0, 0.0), 100.0, 16.0), UiPalette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-64.0, 0.0), Vector2(64.0, 0.0), Vector2(40.0, -240.0), Vector2(-38.0, -242.0),
	]), WALL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(34.0, 0.0), Vector2(64.0, 0.0), Vector2(40.0, -240.0), Vector2(22.0, -240.0),
	]), WALL.darkened(0.18))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-50.0, -236.0), Vector2(52.0, -234.0), Vector2(30.0, -286.0), Vector2(-4.0, -300.0), Vector2(-32.0, -284.0),
	]), CAP)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18.0, 0.0), Vector2(14.0, 0.0), Vector2(14.0, -60.0), Vector2(-2.0, -70.0), Vector2(-18.0, -60.0),
	]), DOOR)
	for i in 4:
		var direction := Vector2.from_angle(_sail_angle + TAU * i / 4.0)
		var side := direction.orthogonal() * SAIL_WIDTH
		var root := HUB_POSITION + direction * 18.0
		var tip := HUB_POSITION + direction * SAIL_LENGTH
		draw_colored_polygon(PackedVector2Array([root, tip, tip + side, root + side * 0.6]), SAIL)
	draw_colored_polygon(FlatProps.octagon(HUB_POSITION, 14.0, 14.0), HUB)
