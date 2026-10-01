class_name SkinAccessory
extends CarAccessory
## Re-covers the whole car instead of sitting anywhere: every body polygon in
## the body's own paint is repainted, a few big pattern plates are cut to that
## polygon's outline, and the wheels get a tint. Its own art is only there for
## the garage icon and is dropped once it's on a car.

enum Pattern { SCUTES, BUBBLES, TAPE }

@export var pattern: Pattern = Pattern.SCUTES
## Off to keep the body's own paint and only add the pattern (duct tape).
@export var repaint: bool = true
@export var paint_color: Color = Color(0.3, 0.33, 0.18)
@export var pattern_color: Color = Color(0.52, 0.5, 0.28)
## Multiplied over each wheel's art, so a wheel keeps its own look.
@export var wheel_tint: Color = Color.WHITE

## Pattern plates per painted polygon, at most. Shell plates keep to the
## art-style budget for repeated elements; bubble wrap is all about the many
## tiny bubbles, and tape needs enough strips to look slapped on everywhere.
const MAX_SCUTES := 22
const MAX_BUBBLES := 90
const MAX_TAPE_PIECES := 16
## Starting plate spacing, as a share of the body's height.
const SCUTE_SPACING_SHARE := 0.45
const BUBBLE_SPACING_SHARE := 0.2
## Keeps a bubble well over the 4 px minimum.
const MIN_BUBBLE_SPACING := 10.0
const PAINT_MATCH_TOLERANCE := 0.03
## Gap between plates, as a share of the plate spacing: the paint showing
## through is the seam.
const PLATE_FILL := 0.8
const TAPE_STRIPS := 6
const TAPE_TILT := 0.55
## Height of the long strip run along the body, from its top (0) to bottom (1).
const TAPE_LENGTHWISE_HEIGHT := 0.3

func attach_to_body(body: CarBody) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	for polygon in _paint_polygons(body):
		if repaint:
			polygon.color = paint_color
		for piece in _pattern_pieces(polygon.polygon):
			var plate := Polygon2D.new()
			plate.name = "SkinPlate"
			plate.polygon = piece
			plate.color = pattern_color
			polygon.add_child(plate)

func paint_wheel(wheel: Node2D) -> void:
	wheel.modulate = wheel_tint

## The body's own polygons wearing its paint colour. A forged body may have no
## polygon left in the catalog colour, so its biggest polygon stands in.
static func _paint_polygons(body: CarBody) -> Array[Polygon2D]:
	var own: Array[Polygon2D] = []
	for node in body.find_children("*", "Polygon2D", true, false):
		if node.owner == body:
			own.append(node as Polygon2D)
	var paint := body.part_data.color if body.part_data != null else Color.WHITE
	var painted: Array[Polygon2D] = []
	painted.assign(own.filter(func(polygon: Polygon2D) -> bool:
		return _close_colors(polygon.color, paint)))
	if painted.is_empty() and not own.is_empty():
		var biggest := own[0]
		for polygon in own:
			if _area(polygon.polygon) > _area(biggest.polygon):
				biggest = polygon
		painted.append(biggest)
	return painted

func _pattern_pieces(outline: PackedVector2Array) -> Array[PackedVector2Array]:
	if outline.size() < 3:
		return []
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	var shapes: Array[PackedVector2Array] = []
	var max_pieces := MAX_SCUTES
	match pattern:
		Pattern.SCUTES:
			shapes = _grid_shapes(bounds, 6, 0.0, maxf(bounds.size.y * SCUTE_SPACING_SHARE, 8.0), MAX_SCUTES)
		Pattern.BUBBLES:
			max_pieces = MAX_BUBBLES
			shapes = _grid_shapes(bounds, 8, PI / 8.0, maxf(bounds.size.y * BUBBLE_SPACING_SHARE, MIN_BUBBLE_SPACING), MAX_BUBBLES)
		Pattern.TAPE:
			max_pieces = MAX_TAPE_PIECES
			shapes = _tape_strips(bounds)
	var pieces: Array[PackedVector2Array] = []
	for shape in shapes:
		for piece in Geometry2D.intersect_polygons(shape, outline):
			if pieces.size() < max_pieces:
				pieces.append(piece)
	return pieces

## Staggered rows of n-gons covering `bounds`, starting at `spacing` and
## growing as much as it takes to stay within `max_pieces`.
static func _grid_shapes(bounds: Rect2, sides: int, angle_offset: float, spacing: float, max_pieces: int) -> Array[PackedVector2Array]:
	while _grid_count(bounds, spacing) > max_pieces:
		spacing *= 1.15
	var shapes: Array[PackedVector2Array] = []
	var row := 0
	var y := bounds.position.y + spacing * 0.5
	while y < bounds.end.y + spacing * 0.5:
		var x := bounds.position.x + spacing * (0.5 if row % 2 == 0 else 1.0)
		while x < bounds.end.x + spacing * 0.5:
			shapes.append(_ngon(Vector2(x, y), spacing * 0.5 * PLATE_FILL, sides, angle_offset))
			x += spacing
		y += spacing * 0.85
		row += 1
	return shapes

static func _grid_count(bounds: Rect2, spacing: float) -> int:
	var columns := ceili(bounds.size.x / spacing) + 1
	var rows := ceili(bounds.size.y / (spacing * 0.85)) + 1
	return columns * rows

## Strips of tape slapped across the body, leaning alternate ways.
static func _tape_strips(bounds: Rect2) -> Array[PackedVector2Array]:
	var strips: Array[PackedVector2Array] = []
	var width := maxf(bounds.size.y * 0.27, 6.0)
	var half_length := bounds.size.y
	for i in TAPE_STRIPS:
		var center := Vector2(lerpf(bounds.position.x, bounds.end.x, (i + 0.5) / TAPE_STRIPS), bounds.get_center().y)
		var along := Vector2.UP.rotated(TAPE_TILT if i % 2 == 0 else -TAPE_TILT)
		strips.append(FlatProps.sliver(center - along * half_length, center + along * half_length, width))
	var lengthwise_y := lerpf(bounds.position.y, bounds.end.y, TAPE_LENGTHWISE_HEIGHT)
	strips.append(FlatProps.sliver(Vector2(bounds.position.x, lengthwise_y + width * 0.3), Vector2(bounds.end.x, lengthwise_y - width * 0.3), width))
	return strips

static func _ngon(center: Vector2, radius: float, sides: int, angle_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in sides:
		points.append(center + Vector2.from_angle(TAU * k / sides + angle_offset) * radius)
	return points

static func _close_colors(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < PAINT_MATCH_TOLERANCE and absf(a.g - b.g) < PAINT_MATCH_TOLERANCE \
			and absf(a.b - b.b) < PAINT_MATCH_TOLERANCE and absf(a.a - b.a) < PAINT_MATCH_TOLERANCE

static func _area(points: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in points.size():
		twice_area += points[i].cross(points[(i + 1) % points.size()])
	return absf(twice_area) * 0.5
