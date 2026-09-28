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
	_poly(_hexagon(Vector2(0.60, 0.66), 0.36), UiPalette.SHADOW)
	var nut := _hexagon(Vector2(0.52, 0.58), 0.36)
	_poly(nut, UiPalette.STEEL_DARK)
	_poly(_hexagon(Vector2(0.52, 0.55), 0.33), UiPalette.STEEL_BASE)
	_poly([nut[0], nut[1], Vector2(0.52, 0.58)], UiPalette.STEEL_SHADE)
	_poly(_hexagon(Vector2(0.52, 0.56), 0.13), UiPalette.VOID)
	_poly([Vector2(0.30, 0.34), Vector2(0.44, 0.28), Vector2(0.40, 0.36)], UiPalette.STEEL_LIGHT)

## Two stacked octagonal coins.
func _draw_money() -> void:
	_poly(_octagon(Vector2(0.58, 0.64), 0.36), UiPalette.SHADOW)
	_poly(_octagon(Vector2(0.62, 0.40), 0.30), COIN_DARK)
	_poly(_octagon(Vector2(0.62, 0.37), 0.28), COIN_SHADE)
	_poly(_octagon(Vector2(0.46, 0.62), 0.36), COIN_DARK)
	_poly(_octagon(Vector2(0.46, 0.58), 0.34), COIN_BASE)
	_poly(_octagon(Vector2(0.46, 0.58), 0.22), COIN_SHADE)
	_poly([Vector2(0.43, 0.44), Vector2(0.50, 0.44), Vector2(0.50, 0.72), Vector2(0.43, 0.72)], COIN_BASE)
	_poly([Vector2(0.22, 0.46), Vector2(0.32, 0.34), Vector2(0.30, 0.44)], UiPalette.CARDBOARD_LIGHT)

## Cardboard tear-off page with a red header and two ring binders.
func _draw_calendar() -> void:
	_poly([Vector2(0.14, 0.18), Vector2(0.98, 0.20), Vector2(0.96, 1.0), Vector2(0.16, 0.98)], UiPalette.SHADOW)
	_poly([Vector2(0.06, 0.14), Vector2(0.90, 0.12), Vector2(0.92, 0.92), Vector2(0.08, 0.94)], UiPalette.CARDBOARD_DARK)
	_poly([Vector2(0.06, 0.14), Vector2(0.90, 0.12), Vector2(0.91, 0.86), Vector2(0.07, 0.88)], UiPalette.CARDBOARD_BASE)
	_poly([Vector2(0.78, 0.12), Vector2(0.90, 0.12), Vector2(0.91, 0.86), Vector2(0.79, 0.87)], UiPalette.CARDBOARD_SHADE)
	_poly([Vector2(0.06, 0.14), Vector2(0.90, 0.12), Vector2(0.90, 0.36), Vector2(0.06, 0.38)], UiPalette.DANGER_RED)
	for ring_x in [0.28, 0.66]:
		_poly([Vector2(ring_x, 0.04), Vector2(ring_x + 0.08, 0.04), Vector2(ring_x + 0.08, 0.24), Vector2(ring_x, 0.24)], UiPalette.METAL_GREY)
	for row in 2:
		for column in 3:
			var cell_origin := Vector2(0.18 + column * 0.22, 0.48 + row * 0.18)
			_poly([cell_origin, cell_origin + Vector2(0.12, 0.0), cell_origin + Vector2(0.12, 0.10), cell_origin + Vector2(0.0, 0.10)], UiPalette.CARDBOARD_DARK)
	_poly([Vector2(0.10, 0.18), Vector2(0.22, 0.17), Vector2(0.12, 0.24)], UiPalette.CARDBOARD_LIGHT)

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
