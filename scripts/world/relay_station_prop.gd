@tool
class_name RelayStationProp
extends StaticBody2D
## One piece of the satellite dish array by the desert hangar: a big dish on a
## concrete pedestal that slowly sweeps the sky, or the little control hut with
## a blinking red light on its mast. Flat polygons, origin on the ground so it
## Y-sorts against the car.

enum Kind { DISH, HUT }

@export var kind: Kind = Kind.DISH:
	set(value):
		kind = value
		queue_redraw()
## Dish only: offsets the sweep so the dishes don't turn in lockstep.
@export var sweep_phase: float = 0.0
## Dish only: where the dish points when the sweep is centred, in degrees
## (0 is straight up, positive leans right).
@export_range(-60.0, 60.0) var aim_degrees: float = 30.0:
	set(value):
		aim_degrees = value
		queue_redraw()

const CONCRETE := Color(0.62, 0.6, 0.55)
const DISH_FACE := Color(0.84, 0.83, 0.79)
const DISH_BACK := Color(0.6, 0.6, 0.58)
const HUT_WALL := Color(0.66, 0.62, 0.52)
const LIGHT_ON := Color(0.9, 0.22, 0.16)
const LIGHT_OFF := Color(0.36, 0.16, 0.14)

const DISH_CENTER := Vector2(0.0, -150.0)
const DISH_RADIUS := 84.0
const DISH_DEPTH := 0.38
const FEED_LENGTH := 74.0
const SWEEP_DEGREES := 18.0
const SWEEP_SPEED := 0.12
const BLINK_TIME := 0.8

var _time := 0.0

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	if Engine.is_editor_hint():
		return
	var footprint := Rect2(-44.0, -16.0, 88.0, 16.0) if kind == Kind.DISH else Rect2(-74.0, -24.0, 148.0, 24.0)
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = footprint.get_center()
	add_child(collision)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	match kind:
		Kind.DISH:
			_draw_dish()
		Kind.HUT:
			_draw_hut()

## Pedestal, then the dish as two offset ellipses (the pale face over the grey
## back gives it its cup), then the feed horn sticking out of the middle.
func _draw_dish() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(12.0, 0.0), 70.0, 16.0), UiPalette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40.0, 0.0), Vector2(-20.0, -140.0), Vector2(20.0, -140.0), Vector2(40.0, 0.0),
	]), CONCRETE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(14.0, 0.0), Vector2(10.0, -140.0), Vector2(20.0, -140.0), Vector2(40.0, 0.0),
	]), CONCRETE.darkened(0.2))
	var sweep := sin(_time * TAU * SWEEP_SPEED + sweep_phase) * SWEEP_DEGREES
	var facing := Vector2.UP.rotated(deg_to_rad(aim_degrees + sweep))
	var across := facing.orthogonal()
	draw_colored_polygon(_ellipse(DISH_CENTER - facing * 12.0, across, facing, DISH_RADIUS, DISH_RADIUS * DISH_DEPTH), DISH_BACK)
	draw_colored_polygon(_ellipse(DISH_CENTER, across, facing, DISH_RADIUS * 0.9, DISH_RADIUS * DISH_DEPTH * 0.85), DISH_FACE)
	var feed_tip := DISH_CENTER + facing * FEED_LENGTH
	draw_colored_polygon(FlatProps.sliver(DISH_CENTER, feed_tip, 8.0), UiPalette.METAL_GREY)
	draw_colored_polygon(FlatProps.octagon(feed_tip, 11.0, 11.0), UiPalette.METAL_GREY)

## A squat block hut with a flat roof slab, a dark door and the blinking light.
func _draw_hut() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(14.0, 0.0), 96.0, 18.0), UiPalette.SHADOW)
	draw_rect(Rect2(-74.0, -96.0, 148.0, 96.0), HUT_WALL)
	draw_rect(Rect2(52.0, -96.0, 22.0, 96.0), HUT_WALL.darkened(0.2))
	draw_rect(Rect2(-84.0, -110.0, 168.0, 16.0), CONCRETE.darkened(0.25))
	draw_rect(Rect2(-46.0, -62.0, 30.0, 62.0), UiPalette.VOID)
	draw_colored_polygon(FlatProps.sliver(Vector2(40.0, -110.0), Vector2(40.0, -170.0), 6.0), UiPalette.METAL_GREY)
	var lit := fmod(_time, BLINK_TIME * 2.0) < BLINK_TIME
	draw_colored_polygon(FlatProps.octagon(Vector2(40.0, -176.0), 9.0, 9.0), LIGHT_ON if lit else LIGHT_OFF)

## A tilted ellipse: `rx` along `across`, `ry` along `along`. Ten sides keeps it
## a toy n-gon rather than a smooth curve.
func _ellipse(center: Vector2, across: Vector2, along: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle := TAU * (float(i) + 0.5) / 10.0
		points.append(center + across * cos(angle) * rx + along * sin(angle) * ry)
	return points
