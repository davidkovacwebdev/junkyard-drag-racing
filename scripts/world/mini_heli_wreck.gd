class_name MiniHeliWreck
extends StaticBody2D
## What's left of Grandpa's homemade helicopter where it came down ("Test
## Pilot"): the bathtub on its side, the tail boom snapped off beside it, the
## blade stuck in the dirt, and a thin wisp of smoke that never quite stops.
## HeliTestStory places it at the crash spot it keeps in Quests.notes, so it
## stays there for good. Origin on the ground under the tub.

const SMOKE := Color(0.3, 0.29, 0.28, 0.55)
const SMOKE_FROM := Vector2(-40.0, -70.0)
const SMOKE_PERIOD := 2.4

var _time := 0.0

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(190.0, 30.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -15.0)
	add_child(collision)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

## Back to front: shadow, the blade in the dirt, the snapped boom with its
## bent tail rotor, the engine, the tub on its side, then the smoke.
func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, 0.0), 150.0, 22.0), UiPalette.SHADOW)
	draw_colored_polygon(FlatProps.sliver(Vector2(70.0, 6.0), Vector2(150.0, -120.0), 9.0), MiniHeli.BLADE)
	draw_colored_polygon(FlatProps.sliver(Vector2(-150.0, 4.0), Vector2(-60.0, -20.0), 14.0), MiniHeli.PIPE)
	draw_colored_polygon(FlatProps.sliver(Vector2(-178.0, -16.0), Vector2(-138.0, 14.0), 9.0), MiniHeli.ENGINE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-80.0, -70.0), Vector2(-20.0, -76.0), Vector2(-14.0, -6.0), Vector2(-78.0, -2.0),
	]), MiniHeli.ENGINE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30.0, -96.0), Vector2(40.0, -110.0), Vector2(94.0, -64.0), Vector2(90.0, -6.0),
		Vector2(-24.0, 0.0),
	]), MiniHeli.TUB)
	draw_colored_polygon(PackedVector2Array([
		Vector2(60.0, -92.0), Vector2(94.0, -64.0), Vector2(90.0, -6.0), Vector2(58.0, -4.0),
	]), MiniHeli.TUB_SHADE)
	# One wisp, rising and fading on a loop.
	var t := fmod(_time, SMOKE_PERIOD) / SMOKE_PERIOD
	var wisp := SMOKE_FROM + Vector2(sin(t * TAU) * 10.0, -110.0 * t)
	var color := SMOKE
	color.a *= 1.0 - t
	draw_colored_polygon(FlatProps.octagon(wisp, 16.0 + 18.0 * t, 13.0 + 14.0 * t), color)
