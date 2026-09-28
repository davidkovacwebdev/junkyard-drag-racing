class_name FlatProps
extends RefCounted
## Small flat-polygon shapes and props shared by the hand-drawn landmarks
## (DragStrip, RampEvent): tyre stacks, oil drums and the basic shapes they are
## cut from. Everything draws into the given canvas in its local space; a
## TriangleBatch works as the canvas too.

const RUBBER_SIDE := Color(0.14, 0.14, 0.14)
const RUBBER_TOP := Color(0.22, 0.22, 0.21)

## A stack of `count` tyres standing on `base` (the bottom tyre's ground centre).
## Each tyre is one slab; alternating tones keep them apart without lines.
static func draw_tire_stack(canvas: Object, base: Vector2, count: int, radius: float = 16.0, tire_height: float = 9.0) -> void:
	canvas.draw_colored_polygon(octagon(base + Vector2(4.0, 3.0), radius, radius * 0.45), UiPalette.SHADOW)
	for i in count:
		var bottom := base.y - i * tire_height
		canvas.draw_rect(Rect2(base.x - radius, bottom - tire_height, radius * 2.0, tire_height), RUBBER_SIDE if i % 2 == 0 else RUBBER_TOP.darkened(0.2))
	var top := Vector2(base.x, base.y - count * tire_height)
	canvas.draw_colored_polygon(octagon(top, radius, radius * 0.45), RUBBER_TOP)
	canvas.draw_colored_polygon(octagon(top, radius * 0.5, radius * 0.22), UiPalette.VOID)

## An upright oil drum standing on `base`, with a shaded side and one hoop.
static func draw_drum(canvas: Object, base: Vector2, color: Color, radius: float = 12.0, height: float = 30.0) -> void:
	canvas.draw_colored_polygon(octagon(base + Vector2(4.0, 2.0), radius, radius * 0.45), UiPalette.SHADOW)
	canvas.draw_rect(Rect2(base.x - radius, base.y - height, radius * 2.0, height), color)
	canvas.draw_rect(Rect2(base.x + radius - 7.0, base.y - height, 7.0, height), color.darkened(0.2))
	canvas.draw_rect(Rect2(base.x - radius, base.y - height * 0.55, radius * 2.0, 4.0), color.darkened(0.3))
	canvas.draw_colored_polygon(octagon(Vector2(base.x, base.y - height), radius, radius * 0.45), color.lightened(0.12))

## A flat bar of `thickness` from `from` to `to` — beams, cracks, streaks.
static func sliver(from: Vector2, to: Vector2, thickness: float) -> PackedVector2Array:
	var side := (to - from).orthogonal().normalized() * thickness * 0.5
	return PackedVector2Array([from - side, to - side, to + side, from + side])

## Eight-sided stand-in for a circle or ellipse; this art has no smooth curves.
static func octagon(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var angle := TAU * (float(i) + 0.5) / 8.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
