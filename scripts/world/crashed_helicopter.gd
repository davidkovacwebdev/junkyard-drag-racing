@tool
class_name CrashedHelicopter
extends StaticBody2D
## A rescue helicopter that came down hard in the desert and never left: nose
## dug into a mound of sand, tail boom snapped and drooping, one skid gone. Its
## gag is the bent rotor blade still on the mast, swinging in the wind and
## creaking (`rotor_creak`, via an AmbientCall in the scene). Flat polygons,
## origin on the ground under the cabin so it Y-sorts against the car.

const BODY := Color(0.78, 0.46, 0.2)
const BOOM := Color(0.66, 0.38, 0.17)
const SAND := Color(0.78, 0.66, 0.44)
const BLADE := UiPalette.METAL_GREY

const MAST_TOP := Vector2(-6.0, -150.0)
const BLADE_LENGTH := 150.0
const BLADE_SWING_DEGREES := 6.0
const BLADE_SWING_SPEED := 0.35

var _time := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(260.0, 30.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(-10.0, -15.0)
	add_child(collision)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()

## Back to front: snapped-off blade in the sand behind, the drooping boom and
## fin, the tipped-forward cabin with its bubble window, the one skid, then the
## sand heaped over the nose. The swinging blade goes on top.
func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, 0.0), 170.0, 22.0), UiPalette.SHADOW)
	draw_colored_polygon(FlatProps.sliver(Vector2(130.0, 4.0), Vector2(190.0, -120.0), 14.0), BLADE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(40.0, -96.0), Vector2(150.0, -84.0), Vector2(200.0, -40.0), Vector2(190.0, -28.0),
		Vector2(140.0, -64.0), Vector2(40.0, -66.0),
	]), BOOM)
	draw_colored_polygon(PackedVector2Array([
		Vector2(184.0, -40.0), Vector2(230.0, -82.0), Vector2(236.0, -54.0), Vector2(204.0, -24.0),
	]), BOOM.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-130.0, -30.0), Vector2(-110.0, -110.0), Vector2(-40.0, -140.0), Vector2(50.0, -124.0),
		Vector2(70.0, -40.0), Vector2(30.0, -6.0), Vector2(-100.0, -4.0),
	]), BODY)
	draw_colored_polygon(PackedVector2Array([
		Vector2(20.0, -126.0), Vector2(50.0, -124.0), Vector2(70.0, -40.0), Vector2(30.0, -6.0), Vector2(14.0, -8.0),
	]), BODY.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-124.0, -40.0), Vector2(-108.0, -104.0), Vector2(-56.0, -126.0), Vector2(-50.0, -60.0),
	]), UiPalette.GLASS)
	draw_colored_polygon(FlatProps.sliver(Vector2(-40.0, 8.0), Vector2(70.0, 2.0), 10.0), UiPalette.METAL_GREY)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-170.0, 6.0), Vector2(-150.0, -22.0), Vector2(-110.0, -34.0), Vector2(-80.0, -14.0), Vector2(-60.0, 8.0),
	]), SAND)
	draw_colored_polygon(FlatProps.sliver(Vector2(-6.0, -134.0), MAST_TOP, 12.0), UiPalette.METAL_GREY)
	var swing := deg_to_rad(sin(_time * TAU * BLADE_SWING_SPEED) * BLADE_SWING_DEGREES)
	var blade_dir := Vector2.from_angle(deg_to_rad(-168.0) + swing)
	var blade_tip := MAST_TOP + blade_dir * BLADE_LENGTH
	draw_colored_polygon(PackedVector2Array([
		MAST_TOP + Vector2(0.0, -6.0), blade_tip + Vector2(0.0, -4.0),
		blade_tip + Vector2(-6.0, 22.0), MAST_TOP + Vector2(0.0, 6.0),
	]), BLADE)
