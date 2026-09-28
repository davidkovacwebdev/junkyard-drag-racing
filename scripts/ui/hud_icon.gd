@tool
class_name HudIcon
extends Control
## Small flat-polygon HUD icon, drawn on a unit square scaled to `size`.

enum Kind { SCRAP, MONEY, CALENDAR }

const COIN_BASE := Color(0.82, 0.64, 0.14)
const COIN_SHADE := Color(0.70, 0.53, 0.10)
const COIN_DARK := Color(0.58, 0.43, 0.08)

@export var kind: Kind = Kind.SCRAP:
	set(value):
		kind = value
		queue_redraw()

func _draw() -> void:
	match kind:
		Kind.SCRAP: _draw_scrap()
		Kind.MONEY: _draw_money()
		Kind.CALENDAR: _draw_calendar()

## A hex nut with a bent strip of sheet metal wedged behind it.
func _draw_scrap() -> void:
	_poly([Vector2(0.52, 0.08), Vector2(0.96, 0.22), Vector2(0.90, 0.40), Vector2(0.50, 0.28)], UiPalette.RUST)
	var nut := _hexagon(Vector2(0.52, 0.58), 0.36)
	_poly(nut, UiPalette.STEEL_BASE)
	_poly([nut[0], nut[1], nut[2], Vector2(0.52, 0.58)], UiPalette.STEEL_SHADE)
	_poly(_hexagon(Vector2(0.52, 0.58), 0.13), UiPalette.VOID)

## Two stacked octagonal coins.
func _draw_money() -> void:
	_poly(_octagon(Vector2(0.62, 0.38), 0.30), COIN_SHADE)
	_poly(_octagon(Vector2(0.46, 0.60), 0.36), COIN_BASE)
	_poly(_octagon(Vector2(0.46, 0.60), 0.18), COIN_DARK)

## Cardboard tear-off page with a red header and two ring binders.
func _draw_calendar() -> void:
	_poly([Vector2(0.06, 0.14), Vector2(0.90, 0.12), Vector2(0.92, 0.92), Vector2(0.08, 0.94)], UiPalette.CARDBOARD_BASE)
	_poly([Vector2(0.76, 0.12), Vector2(0.90, 0.12), Vector2(0.92, 0.92), Vector2(0.77, 0.93)], UiPalette.CARDBOARD_SHADE)
	_poly([Vector2(0.06, 0.14), Vector2(0.90, 0.12), Vector2(0.90, 0.38), Vector2(0.06, 0.40)], UiPalette.DANGER_RED)
	for ring_x in [0.22, 0.60]:
		_poly([Vector2(ring_x, 0.02), Vector2(ring_x + 0.15, 0.02), Vector2(ring_x + 0.15, 0.24), Vector2(ring_x, 0.24)], UiPalette.METAL_GREY)

func _poly(unit_points: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for p in unit_points:
		points.append(p * size)
	draw_colored_polygon(points, color)

func _hexagon(center: Vector2, radius: float) -> Array:
	return _ring(center, radius, 6, 0.0)

func _octagon(center: Vector2, radius: float) -> Array:
	return _ring(center, radius, 8, PI / 8.0)

func _ring(center: Vector2, radius: float, sides: int, start_angle: float) -> Array:
	var points := []
	for i in sides:
		var angle := start_angle + TAU * i / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
