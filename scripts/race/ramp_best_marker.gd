class_name RampBestMarker
extends Node2D
## The ramp jump's personal best, standing where that car came to rest: a
## see-through silhouette of the car in the pose it stopped in, and a
## cardboard sign on a post reading the distance.

const SILHOUETTE_COLOR := Color(UiPalette.INK, 0.35)
const POST_WIDTH := 12.0
const POST_HEIGHT := 320.0
const SIGN_SIZE := Vector2(300.0, 120.0)
const SIGN_TILT := 0.04
const SHADE_WIDTH := 14.0
const FONT_SIZE := 44

## Builds the marker. `silhouette` is in the marker's own space.
static func create(distance: float, silhouette: Array[PackedVector2Array]) -> RampBestMarker:
	var marker := RampBestMarker.new()
	marker.name = "RampBestMarker"
	# A CanvasGroup flattens the overlapping part polygons into one shape, so
	# the see-through fill is even instead of darker where parts overlap.
	var ghost := CanvasGroup.new()
	ghost.self_modulate = SILHOUETTE_COLOR
	marker.add_child(ghost)
	var ground_y := 0.0
	for outline in silhouette:
		var polygon_node := Polygon2D.new()
		polygon_node.polygon = outline
		ghost.add_child(polygon_node)
		for point in outline:
			ground_y = maxf(ground_y, point.y)
	marker._build_sign(distance, ground_y)
	return marker

func _build_sign(distance: float, ground_y: float) -> void:
	var sign_root := Node2D.new()
	sign_root.position = Vector2(0.0, ground_y)
	sign_root.rotation = SIGN_TILT
	add_child(sign_root)
	var board_top := -POST_HEIGHT - SIGN_SIZE.y
	var half_width := SIGN_SIZE.x / 2.0
	_add_polygon(sign_root, UiPalette.POST_GREY, PackedVector2Array([
		Vector2(-POST_WIDTH / 2.0, 0.0), Vector2(POST_WIDTH / 2.0, 0.0),
		Vector2(POST_WIDTH / 2.0, -POST_HEIGHT), Vector2(-POST_WIDTH / 2.0, -POST_HEIGHT)]))
	_add_polygon(sign_root, UiPalette.CARDBOARD_BASE, PackedVector2Array([
		Vector2(-half_width, board_top + 4.0), Vector2(half_width, board_top),
		Vector2(half_width - 3.0, -POST_HEIGHT), Vector2(-half_width, -POST_HEIGHT + 3.0)]))
	_add_polygon(sign_root, UiPalette.CARDBOARD_SHADE, PackedVector2Array([
		Vector2(-half_width, -POST_HEIGHT + 3.0 - SHADE_WIDTH), Vector2(half_width - 3.0, -POST_HEIGHT - SHADE_WIDTH),
		Vector2(half_width - 3.0, -POST_HEIGHT), Vector2(-half_width, -POST_HEIGHT + 3.0)]))
	var label := Label.new()
	label.text = "BEST\n%s" % format_distance(distance)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", UiPalette.TEXT_BROWN)
	label.add_theme_constant_override("line_spacing", -8)
	label.position = Vector2(-half_width, board_top)
	label.size = Vector2(SIGN_SIZE.x, SIGN_SIZE.y - SHADE_WIDTH)
	sign_root.add_child(label)

static func format_distance(distance: float) -> String:
	return "%.1f m" % distance

static func _add_polygon(parent: Node, color: Color, points: PackedVector2Array) -> void:
	var polygon_node := Polygon2D.new()
	polygon_node.color = color
	polygon_node.polygon = points
	parent.add_child(polygon_node)
