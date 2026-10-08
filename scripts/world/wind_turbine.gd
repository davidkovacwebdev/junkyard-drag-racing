@tool
class_name WindTurbine
extends StaticBody2D
## One tall white turbine of the wind farm on the eastern scrub. Three blades
## turn slowly, each at its own phase so the farm never spins in lockstep, and
## a soft `turbine_whoosh` (AmbientCall in the scene) sweeps past now and then.
## Origin on the ground at the foot of the mast.

const MAST := Color(0.9, 0.9, 0.88)
const BLADE := Color(0.95, 0.95, 0.93)
const NACELLE := Color(0.8, 0.81, 0.8)

const MAST_HEIGHT := 520.0
const BLADE_LENGTH := 210.0
const SPIN_SPEED := 0.7

var _blade_angle := 0.0

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	_blade_angle = fposmod(global_position.x * 0.013 + global_position.y * 0.007, TAU)
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(52.0, 22.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -11.0)
	add_child(collision)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_blade_angle = wrapf(_blade_angle + SPIN_SPEED * delta, 0.0, TAU)
	queue_redraw()

## Tapering mast with a shade strip, the nacelle box, then three blades and
## the hub on top.
func _draw() -> void:
	var hub := Vector2(0.0, -MAST_HEIGHT)
	draw_colored_polygon(FlatProps.octagon(Vector2(6.0, 0.0), 44.0, 9.0), UiPalette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17.0, 0.0), Vector2(17.0, 0.0), Vector2(8.0, -MAST_HEIGHT), Vector2(-8.0, -MAST_HEIGHT),
	]), MAST)
	draw_colored_polygon(PackedVector2Array([
		Vector2(6.0, 0.0), Vector2(17.0, 0.0), Vector2(8.0, -MAST_HEIGHT), Vector2(3.0, -MAST_HEIGHT),
	]), MAST.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([
		hub + Vector2(-12.0, -16.0), hub + Vector2(48.0, -14.0), hub + Vector2(52.0, 12.0), hub + Vector2(-12.0, 14.0),
	]), NACELLE)
	for i in 3:
		var direction := Vector2.from_angle(_blade_angle + TAU * i / 3.0)
		var side := direction.orthogonal()
		var tip := hub + direction * BLADE_LENGTH
		draw_colored_polygon(PackedVector2Array([
			hub + side * 9.0, hub + direction * 60.0 + side * 13.0, tip + side * 4.0, tip - side * 3.0, hub - side * 7.0,
		]), BLADE)
	draw_colored_polygon(FlatProps.octagon(hub, 13.0, 13.0), NACELLE.darkened(0.2))
