@tool
class_name HangarPiece
extends Node2D
## One layer of the desert `Hangar`, split by where it sits in the Y-sort: the
## concrete floor and apron (origin on the back wall line, under everything),
## the interior back and side walls (also on the back wall line, only shown in
## cutaway), and the front facade (origin on the front wall line, in front of
## anything inside).
##
## The facade is a big steel box under a shallow arched roof, one giant dark
## door and a painted star over it.

enum Kind { FLOOR, INTERIOR, FACADE }

@export var kind: Kind = Kind.FACADE:
	set(value):
		kind = value
		queue_redraw()

## 0 with the player outside, 1 with them inside. The facade fades out as this
## rises, and the interior walls fade in.
var reveal := 0.0:
	set(value):
		reveal = value
		queue_redraw()

const STEEL := Color(0.56, 0.58, 0.52)
const STEEL_SHADE := Color(0.45, 0.47, 0.42)
const ROOF := Color(0.38, 0.4, 0.38)
const DOORWAY := Color(0.15, 0.16, 0.15)
const CONCRETE := Color(0.5, 0.49, 0.46)
const CONCRETE_INSIDE := Color(0.42, 0.41, 0.39)
const STAR := UiPalette.TRIM_OFF_WHITE

const ROOF_THICKNESS := 16.0
const ROOF_OVERHANG := 12.0
const SHADE_WIDTH := 36.0
const STAR_CENTER := Vector2(0.0, -255.0)
const STAR_RADIUS := 34.0

func _draw() -> void:
	match kind:
		Kind.FLOOR:
			_draw_floor()
		Kind.INTERIOR:
			_draw_interior()
		Kind.FACADE:
			_draw_facade()

func _draw_floor() -> void:
	var half := Hangar.WIDTH / 2.0
	draw_rect(Rect2(-half, 0.0, Hangar.WIDTH, Hangar.DEPTH), CONCRETE_INSIDE)
	var door_half := Hangar.DOOR_WIDTH / 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-door_half - 20.0, Hangar.DEPTH), Vector2(door_half + 20.0, Hangar.DEPTH),
		Vector2(door_half + 56.0, Hangar.DEPTH + Hangar.APRON),
		Vector2(-door_half - 48.0, Hangar.DEPTH + Hangar.APRON - 6.0),
	]), CONCRETE)

func _draw_interior() -> void:
	if reveal <= 0.0:
		return
	var half := Hangar.WIDTH / 2.0
	draw_rect(Rect2(-half, -Hangar.BACK_WALL_HEIGHT, Hangar.WIDTH, Hangar.BACK_WALL_HEIGHT + Hangar.WALL),
			Color(STEEL_SHADE, reveal))
	draw_rect(Rect2(-half, 0.0, Hangar.WALL, Hangar.DEPTH), Color(STEEL, reveal))
	draw_rect(Rect2(half - Hangar.WALL, 0.0, Hangar.WALL, Hangar.DEPTH), Color(STEEL, reveal))

func _draw_facade() -> void:
	var half := Hangar.WIDTH / 2.0
	var shown := 1.0 - reveal
	if reveal > 0.0:
		var stub := half - Hangar.DOOR_WIDTH / 2.0
		draw_rect(Rect2(-half, -Hangar.WALL, stub, Hangar.WALL), Color(STEEL, reveal))
		draw_rect(Rect2(Hangar.DOOR_WIDTH / 2.0, -Hangar.WALL, stub, Hangar.WALL), Color(STEEL, reveal))
	if shown <= 0.0:
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half + 8.0, -10.0), Vector2(half + 6.0, -10.0),
		Vector2(half + 24.0, 10.0), Vector2(-half + 22.0, 10.0),
	]), Color(UiPalette.SHADOW, UiPalette.SHADOW.a * shown))
	var wall := _roof_line(half, 0.0)
	wall.append(Vector2(half, 0.0))
	wall.append(Vector2(-half, 0.0))
	draw_colored_polygon(wall, Color(STEEL, shown))
	draw_colored_polygon(PackedVector2Array([
		Vector2(half - SHADE_WIDTH, _roof_y(half - SHADE_WIDTH, half, 0.0)), Vector2(half, -Hangar.DEPTH),
		Vector2(half, 0.0), Vector2(half - SHADE_WIDTH, 0.0),
	]), Color(STEEL_SHADE, shown))
	var band := _roof_line(half + ROOF_OVERHANG, ROOF_THICKNESS)
	var under := _roof_line(half + ROOF_OVERHANG, 0.0)
	under.reverse()
	band.append_array(under)
	draw_colored_polygon(band, Color(ROOF, shown))
	draw_rect(Rect2(-Hangar.DOOR_WIDTH / 2.0, -Hangar.DOOR_HEIGHT, Hangar.DOOR_WIDTH, Hangar.DOOR_HEIGHT),
			Color(DOORWAY, shown))
	draw_colored_polygon(_star(STAR_CENTER, STAR_RADIUS), Color(STAR, shown))

## The top edge of the facade, a shallow arch from one eave to the other,
## lifted by `lift`.
func _roof_line(reach: float, lift: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 8
	for i in steps + 1:
		var x := lerpf(-reach, reach, float(i) / steps)
		points.append(Vector2(x, _roof_y(x, reach, lift)))
	return points

func _roof_y(x: float, reach: float, lift: float) -> float:
	var t := clampf(x / reach, -1.0, 1.0)
	return -Hangar.DEPTH - lift - Hangar.ROOF_RISE * (1.0 - t * t)

func _star(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var tilt := deg_to_rad(3.0)
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.42
		var angle := -PI / 2.0 + tilt + TAU * i / 10.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
