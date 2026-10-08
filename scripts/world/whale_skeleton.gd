@tool
class_name WhaleSkeleton
extends StaticBody2D
## Bleached whale bones washed up on the west islet: a big blunt skull, the
## spine running back along the sand and four ribs arching up off it. Wind
## whistles through the ribs (`rib_whistle`, AmbientCall in the scene). Origin
## on the ground under the middle of the spine.

const BONE := Color(0.91, 0.88, 0.8)
const BONE_SHADE := Color(0.79, 0.75, 0.66)

const RIB_XS: Array[float] = [-120.0, -30.0, 60.0, 150.0]
const RIB_HEIGHTS: Array[float] = [190.0, 210.0, 185.0, 140.0]
const RIB_THICKNESS := 18.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(640.0, 36.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(-40.0, -18.0)
	add_child(collision)

## Shadow, spine bar, four ribs (each one bent bar curling toward the tail),
## then the long tapering skull with its jaw shade at the left end.
func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(-30.0, 0.0), 360.0, 30.0), UiPalette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-180.0, -16.0), Vector2(250.0, -6.0), Vector2(280.0, 8.0), Vector2(-180.0, 6.0),
	]), BONE_SHADE)
	for i in RIB_XS.size():
		var x := RIB_XS[i]
		var h := RIB_HEIGHTS[i]
		var t := RIB_THICKNESS
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - t * 0.5, 0.0), Vector2(x - t * 0.5, -h * 0.7), Vector2(x + 30.0, -h),
			Vector2(x + 76.0, -h * 0.9), Vector2(x + 70.0, -h * 0.9 + t), Vector2(x + 32.0, -h + t),
			Vector2(x + t * 0.5, -h * 0.7 + t * 0.4), Vector2(x + t * 0.5, 0.0),
		]), BONE if i % 2 == 0 else BONE.darkened(0.06))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-400.0, -6.0), Vector2(-330.0, -60.0), Vector2(-230.0, -120.0), Vector2(-160.0, -116.0),
		Vector2(-140.0, -40.0), Vector2(-160.0, 0.0), Vector2(-380.0, 4.0),
	]), BONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-400.0, -6.0), Vector2(-160.0, -26.0), Vector2(-140.0, -40.0), Vector2(-160.0, 0.0), Vector2(-380.0, 4.0),
	]), BONE_SHADE)
