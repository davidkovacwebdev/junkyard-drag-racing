@tool
class_name HillClimbSite
extends Node2D
## The hill climb on the world map: a big grey rock mountain with a snow cap,
## a dirt road zigzagging up its face to a red summit flag, a couple of
## boulders at its foot and a HILL CLIMB board by the start. The mountain is
## solid; the board's lettering is drawn after the batch.
##
## @tool so it's visible in the editor.

const ROCK := Color(0.45, 0.43, 0.41)
const ROCK_SHADE := Color(0.37, 0.35, 0.34)
const SNOW := Color(0.88, 0.89, 0.90)
const DIRT := UiPalette.SURFACE_BASE
const BOARD := Color(0.85, 0.66, 0.12)
const SUMMIT_FLAG := UiPalette.DANGER_RED

const MOUNTAIN_RADIUS := Vector2(640.0, 420.0)
const ROAD_WIDTH := 56.0
## The road's corners, foot to summit.
const ROAD_POINTS: Array[Vector2] = [
	Vector2(-760.0, 330.0), Vector2(-120.0, 300.0), Vector2(-420.0, 110.0),
	Vector2(170.0, -20.0), Vector2(-160.0, -190.0), Vector2(40.0, -290.0),
]
const BOULDERS: Array[Vector3] = [Vector3(420.0, 330.0, 70.0), Vector3(560.0, 260.0, 48.0)]
const BOARD_RECT := Rect2(-980.0, 120.0, 230.0, 66.0)
const BOARD_POST_HEIGHT := 60.0

var _art := TriangleBatch.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	RoundedRectShape.add_solid(self, Rect2(-MOUNTAIN_RADIUS * 0.75, MOUNTAIN_RADIUS * 1.4))
	for boulder in BOULDERS:
		RoundedRectShape.add_solid(self, Rect2(boulder.x - boulder.z, boulder.y - boulder.z * 0.5, boulder.z * 2.0, boulder.z))
	RoundedRectShape.add_solid(self, Rect2(BOARD_RECT.position.x, BOARD_RECT.end.y + BOARD_POST_HEIGHT - 16.0, BOARD_RECT.size.x, 16.0))

func _draw() -> void:
	_art.clear()
	_art.draw_colored_polygon(FlatProps.octagon(Vector2(20.0, 20.0), MOUNTAIN_RADIUS.x, MOUNTAIN_RADIUS.y), UiPalette.SHADOW)
	_art.draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, MOUNTAIN_RADIUS.x, MOUNTAIN_RADIUS.y), ROCK)
	_art.draw_colored_polygon(PackedVector2Array([
		Vector2(MOUNTAIN_RADIUS.x * 0.92, -MOUNTAIN_RADIUS.y * 0.38),
		Vector2(MOUNTAIN_RADIUS.x * 0.92, MOUNTAIN_RADIUS.y * 0.38),
		Vector2(MOUNTAIN_RADIUS.x * 0.38, MOUNTAIN_RADIUS.y * 0.92),
		Vector2(0.0, MOUNTAIN_RADIUS.y * 0.92),
		Vector2(150.0, 0.0),
	]), ROCK_SHADE)
	_art.draw_colored_polygon(FlatProps.octagon(Vector2(30.0, -250.0), 230.0, 120.0), SNOW)
	for i in ROAD_POINTS.size() - 1:
		_art.draw_colored_polygon(FlatProps.sliver(ROAD_POINTS[i], ROAD_POINTS[i + 1], ROAD_WIDTH), DIRT)
	var summit: Vector2 = ROAD_POINTS[ROAD_POINTS.size() - 1]
	_art.draw_rect(Rect2(summit.x - 5.0, summit.y - 130.0, 10.0, 130.0), UiPalette.STEEL_SHADE)
	_art.draw_colored_polygon(PackedVector2Array([
		summit + Vector2(5.0, -130.0), summit + Vector2(80.0, -110.0), summit + Vector2(5.0, -88.0),
	]), SUMMIT_FLAG)
	for boulder in BOULDERS:
		_art.draw_colored_polygon(FlatProps.octagon(Vector2(boulder.x, boulder.y), boulder.z, boulder.z * 0.7), ROCK)
		_art.draw_colored_polygon(FlatProps.octagon(Vector2(boulder.x + boulder.z * 0.3, boulder.y + boulder.z * 0.2), boulder.z * 0.6, boulder.z * 0.45), ROCK_SHADE)
	for post_x: float in [BOARD_RECT.position.x + 30.0, BOARD_RECT.end.x - 38.0]:
		_art.draw_rect(Rect2(post_x, BOARD_RECT.end.y, 8.0, BOARD_POST_HEIGHT), UiPalette.POST_GREY)
	_art.draw_rect(BOARD_RECT, BOARD)
	_art.draw_rect(Rect2(BOARD_RECT.end.x - 12.0, BOARD_RECT.position.y, 12.0, BOARD_RECT.size.y), BOARD.darkened(0.2))
	_art.commit(self)
	_art.clear()
	draw_string(ThemeDB.fallback_font, BOARD_RECT.position + Vector2(0.0, 46.0), "HILL CLIMB",
			HORIZONTAL_ALIGNMENT_CENTER, BOARD_RECT.size.x - 12.0, 34, UiPalette.DANGER_RED)
