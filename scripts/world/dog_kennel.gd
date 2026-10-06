@tool
class_name DogKennel
extends StaticBody2D
## The yard dog's kennel: a wooden box with a peaked red roof, a dark round
## door and a dented food bowl out front as its one gag. Origin on the ground;
## the collision footprint hugs the base.

const WOOD := Color(0.6, 0.44, 0.27)
const ROOF := Color(0.62, 0.2, 0.16)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100.0, 16.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -8.0)
	add_child(collision)

func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(8.0, 0.0), 62.0, 10.0), UiPalette.SHADOW)
	draw_rect(Rect2(-50.0, -70.0, 100.0, 70.0), WOOD)
	draw_rect(Rect2(34.0, -70.0, 16.0, 70.0), WOOD.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-62.0, -64.0), Vector2(-2.0, -112.0), Vector2(62.0, -66.0), Vector2(50.0, -60.0), Vector2(-50.0, -58.0),
	]), ROOF)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22.0, 0.0), Vector2(-22.0, -30.0), Vector2(-12.0, -44.0), Vector2(6.0, -44.0),
		Vector2(16.0, -30.0), Vector2(16.0, 0.0),
	]), UiPalette.VOID)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-62.0, 16.0), Vector2(-60.0, 4.0), Vector2(-34.0, 6.0), Vector2(-38.0, 16.0),
	]), UiPalette.METAL_GREY)
