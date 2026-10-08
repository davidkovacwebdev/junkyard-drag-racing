@tool
class_name Boulder
extends StaticBody2D
## A big grey rock on the scrub: a chunky lump, its shade side and one lit top
## face. `size` scales the whole rock (and its footprint) so a cluster reads as
## a few different stones. Origin on the ground under the rock.

const ROCK := Color(0.6, 0.6, 0.57)

@export var size: float = 1.0:
	set(value):
		size = value
		queue_redraw()
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(150.0, 30.0) * size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -15.0 * size)
	add_child(collision)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-size if flip_h else size, size))
	draw_colored_polygon(FlatProps.octagon(Vector2(8.0, 0.0), 92.0, 14.0), UiPalette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-80.0, 0.0), Vector2(-70.0, -52.0), Vector2(-30.0, -86.0), Vector2(26.0, -92.0),
		Vector2(66.0, -60.0), Vector2(82.0, 0.0),
	]), ROCK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(26.0, -92.0), Vector2(66.0, -60.0), Vector2(82.0, 0.0), Vector2(36.0, 0.0), Vector2(40.0, -50.0),
	]), ROCK.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-70.0, -52.0), Vector2(-30.0, -86.0), Vector2(26.0, -92.0), Vector2(40.0, -50.0), Vector2(-20.0, -44.0),
	]), ROCK.lightened(0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
