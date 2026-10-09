@tool
class_name TriangleBatch
extends RefCounted
## Collects flat-colored shapes into one triangle list and submits it to a
## canvas item as a single draw command. The Compatibility renderer spends a
## draw call on every polygon and every anti-aliased line, so art made of
## hundreds of small shapes is far cheaper committed as one batch.
##
## `draw_colored_polygon` and `draw_rect` mirror CanvasItem's own names, so a
## batch can be handed to a helper written against a canvas (see FlatProps).
## Shapes keep the order they were added in, exactly like separate draw calls.

## Soft edge added outside a line, in local units, standing in for the
## renderer's own anti-aliasing.
const LINE_FEATHER := 1.0

var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

func draw_colored_polygon(polygon: PackedVector2Array, color: Color) -> void:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.is_empty():
		return
	var start := _points.size()
	_points.append_array(polygon)
	for i in polygon.size():
		_colors.append(color)
	for index in triangles:
		_indices.append(start + index)

func draw_rect(rect: Rect2, color: Color) -> void:
	_add_quad(rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y), color, color)

## A straight line `width` wide with a feathered edge, like an anti-aliased
## `draw_line`.
func add_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var direction := to - from
	if direction.length_squared() <= 0.0:
		return
	var side := direction.orthogonal().normalized()
	var core := side * width * 0.5
	var outer := side * (width * 0.5 + LINE_FEATHER)
	var clear := Color(color, 0.0)
	_add_quad(from - core, to - core, to + core, from + core, color, color)
	_add_quad(from + core, to + core, to + outer, from + outer, color, clear)
	_add_quad(from - core, to - core, to - outer, from - outer, color, clear)

## Pairs of points, one line per pair, like `draw_multiline`.
func add_segments(segments: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(0, segments.size() - 1, 2):
		add_line(segments[i], segments[i + 1], color, width)

## Ready-made triangles, e.g. built natively (see RoadGeometry).
func add_triangles(points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	if is_empty():
		# Copies, never the caller's own arrays: packed arrays are shared by
		# reference, and a cloud template's `indices` adopted here would grow
		# under the next add of that same template while it's being iterated
		# (an endless loop, the rain-day freeze).
		_points = points.duplicate()
		_colors = colors.duplicate()
		_indices = indices.duplicate()
		return
	var start := _points.size()
	_points.append_array(points)
	_colors.append_array(colors)
	for index in indices:
		_indices.append(start + index)

func is_empty() -> bool:
	return _indices.is_empty()

## Must be called from inside `canvas`'s draw pass, like any other draw call.
func commit(canvas: CanvasItem) -> void:
	if is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), _indices, _points, _colors)

func clear() -> void:
	_points.clear()
	_colors.clear()
	_indices.clear()

## Quad a-b-c-d, with a and b taking `near_color` and c and d `far_color`.
func _add_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, near_color: Color, far_color: Color) -> void:
	var start := _points.size()
	_points.append_array([a, b, c, d])
	_colors.append_array([near_color, near_color, far_color, far_color])
	_indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
