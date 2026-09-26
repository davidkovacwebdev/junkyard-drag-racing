class_name ScrapBoard
extends RefCounted
## Draws one salvaged board — the building block of every UI panel and button.
## Back to front: shadow, skirt, body, shade strip, nails, highlight. No outline:
## edges come from the shapes' own tone steps against each other.
## The corners are jittered from a seed and the whole board is tilted, so no two
## boards are perfect boxes, and the same seed always gives the same board.

var body_color := UiPalette.SURFACE_BASE
var shade_color := UiPalette.SURFACE_SHADE
var skirt_color := UiPalette.SURFACE_DARK
var nail_color := UiPalette.METAL_GREY
## Transparent = no highlight.
var highlight_color := Color.TRANSPARENT
var tilt_degrees: float = 0.0
var jitter: float = 3.0
var jitter_seed: int = 0
var skirt_height: float = 7.0
var shadow_offset := Vector2(5.0, 6.0)
var shade_fraction: float = 0.08
## Big boards keep a narrow shade strip instead of a wide dark column.
var max_shade_width: float = 16.0
var nails: bool = true

## The body's rectangle after `press_depth` is applied, before tilt. Text sits
## in here so it rides the body down when a button is pressed.
static func body_rect(rect: Rect2, skirt: float, press_depth: float) -> Rect2:
	return Rect2(rect.position + Vector2(0.0, press_depth), rect.size - Vector2(0.0, skirt))

func draw(canvas: CanvasItem, rect: Rect2, press_depth: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = jitter_seed
	var corners := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	for i in corners.size():
		corners[i] += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
	var pivot := rect.get_center()
	var angle := deg_to_rad(tilt_degrees)

	_fill(canvas, _offset(corners, shadow_offset), UiPalette.SHADOW, pivot, angle)
	_fill(canvas, corners, skirt_color, pivot, angle)

	var body_bottom := skirt_height - press_depth
	var body := PackedVector2Array([
		corners[0] + Vector2(0.0, press_depth),
		corners[1] + Vector2(0.0, press_depth),
		corners[2] - Vector2(0.0, body_bottom),
		corners[3] - Vector2(0.0, body_bottom),
	])
	_fill(canvas, body, body_color, pivot, angle)

	var shade_width := minf(rect.size.x * shade_fraction, max_shade_width)
	var shade_start := 1.0 - shade_width / maxf(rect.size.x, 1.0)
	var shade_left_top := body[0].lerp(body[1], shade_start)
	var shade_left_bottom := body[3].lerp(body[2], shade_start)
	_fill(canvas, PackedVector2Array([shade_left_top, body[1], body[2], shade_left_bottom]), shade_color, pivot, angle)

	if nails:
		for corner in [body[0] + Vector2(8.0, 7.0), body[1] + Vector2(-8.0 - shade_width, 7.0)]:
			_fill(canvas, _square(corner, 2.5), nail_color, pivot, angle)

	if highlight_color.a > 0.0:
		var sliver_top := body[0] + Vector2(4.0, 4.0)
		var sliver_bottom := body[3] + Vector2(4.0, -4.0)
		_fill(canvas, PackedVector2Array([sliver_top, sliver_top + Vector2(7.0, 0.0),
				sliver_bottom + Vector2(5.0, 0.0), sliver_bottom]), highlight_color, pivot, angle)

static func _fill(canvas: CanvasItem, points: PackedVector2Array, color: Color, pivot: Vector2, angle: float) -> void:
	var turned := PackedVector2Array()
	for p in points:
		turned.append(pivot + (p - pivot).rotated(angle))
	canvas.draw_colored_polygon(turned, color)

static func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + by)
	return out

static func _square(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-half, -half), center + Vector2(half, -half),
			center + Vector2(half, half), center + Vector2(-half, half)])
