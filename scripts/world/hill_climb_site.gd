@tool
class_name HillClimbSite
extends Node2D
## The hill climb on the world map: a big grey rock mountain standing on the
## ground, with a snow cap, a dirt road switchbacking up its face to a red
## summit flag, a couple of boulders at its foot and a HILL CLIMB board by the
## start.
##
## Origin is the mountain's ground line, its y-sort point, so the car drives
## behind it as well as in front. The boulders and the board are child canvases
## at their own ground points so each one sorts on its own (the scene sets
## `y_sort_enabled` on this node for that). Only the foot of each is solid.
##
## @tool so it's visible in the editor.

const ROCK := Color(0.45, 0.43, 0.41)
const ROCK_SHADE := Color(0.37, 0.35, 0.34)
const SNOW := Color(0.88, 0.89, 0.90)
const DIRT := UiPalette.SURFACE_BASE
const BOARD := Color(0.85, 0.66, 0.12)
const SUMMIT_FLAG := UiPalette.DANGER_RED

const HALF_WIDTH := 620.0
const HEIGHT := 560.0
## The mountain's outline, foot to foot, as (x, height) shares of HALF_WIDTH and
## HEIGHT. Lopsided and lumpy: a shoulder on the left, the peak just left of centre.
const OUTLINE: Array[Vector2] = [
	Vector2(-1.0, 0.0), Vector2(-0.78, 0.2), Vector2(-0.6, 0.42), Vector2(-0.42, 0.5),
	Vector2(-0.26, 0.74), Vector2(-0.08, 1.0), Vector2(0.1, 0.92), Vector2(0.28, 0.72),
	Vector2(0.46, 0.62), Vector2(0.66, 0.38), Vector2(0.84, 0.16), Vector2(1.0, 0.0),
]
const PEAK_INDEX := 5
const SNOW_CAP: Array[Vector2] = [
	Vector2(-0.17, 0.82), Vector2(-0.08, 1.0), Vector2(0.1, 0.92), Vector2(0.2, 0.8),
	Vector2(0.08, 0.75), Vector2(-0.02, 0.82), Vector2(-0.1, 0.74),
]
## The road's corners, foot to summit, in the same shares.
const ROAD: Array[Vector2] = [
	Vector2(-1.15, 0.0), Vector2(-0.55, 0.12), Vector2(-0.62, 0.3), Vector2(-0.2, 0.42),
	Vector2(-0.36, 0.56), Vector2(-0.05, 0.75), Vector2(-0.08, 0.98),
]
const ROAD_WIDTH := 44.0
## How deep (along y) the solid strip along the mountain's foot is.
const FOOT_DEPTH := 70.0

## (x, y, radius) of each boulder's ground point, in this node's space.
const BOULDERS: Array[Vector3] = [Vector3(450.0, 40.0, 60.0), Vector3(600.0, 18.0, 42.0)]
## Where the board's posts meet the ground, and the board's size.
const BOARD_BASE := Vector2(-865.0, -84.0)
const BOARD_SIZE := Vector2(230.0, 66.0)
const BOARD_POST_HEIGHT := 60.0

var _art := TriangleBatch.new()

func _ready() -> void:
	for boulder in BOULDERS:
		_add_piece(Vector2(boulder.x, boulder.y), _draw_boulder.bind(boulder.z))
	_add_piece(BOARD_BASE, _draw_board)
	if Engine.is_editor_hint():
		return
	RoundedRectShape.add_solid(self, Rect2(-HALF_WIDTH * 0.95, -FOOT_DEPTH, HALF_WIDTH * 1.9, FOOT_DEPTH))
	for boulder in BOULDERS:
		RoundedRectShape.add_solid(self, Rect2(boulder.x - boulder.z, boulder.y - boulder.z * 0.4, boulder.z * 2.0, boulder.z * 0.4))
	RoundedRectShape.add_solid(self, Rect2(BOARD_BASE.x - BOARD_SIZE.x * 0.5, BOARD_BASE.y - 16.0, BOARD_SIZE.x, 16.0))

## A child canvas standing at `ground`, drawn by `drawer(canvas, ...bound)`.
func _add_piece(ground: Vector2, drawer: Callable) -> void:
	var piece := Node2D.new()
	piece.position = ground
	piece.draw.connect(func() -> void: drawer.call(piece))
	add_child(piece)

func _draw() -> void:
	_art.clear()
	var outline := _scaled(OUTLINE)
	_art.draw_colored_polygon(FlatProps.octagon(Vector2(30.0, 4.0), HALF_WIDTH + 40.0, 34.0), UiPalette.SHADOW)
	_art.draw_colored_polygon(outline, ROCK)
	var flank := outline.slice(PEAK_INDEX)
	flank.append(Vector2(HALF_WIDTH * 0.2, 0.0))
	_art.draw_colored_polygon(flank, ROCK_SHADE)
	_art.draw_colored_polygon(_scaled(SNOW_CAP), SNOW)
	var road := _scaled(ROAD)
	for i in road.size() - 1:
		_art.draw_colored_polygon(FlatProps.sliver(road[i], road[i + 1], ROAD_WIDTH), DIRT)
	var summit := road[road.size() - 1]
	_art.draw_rect(Rect2(summit.x - 5.0, summit.y - 130.0, 10.0, 130.0), UiPalette.STEEL_SHADE)
	_art.draw_colored_polygon(PackedVector2Array([
		summit + Vector2(5.0, -130.0), summit + Vector2(80.0, -110.0), summit + Vector2(5.0, -88.0),
	]), SUMMIT_FLAG)
	_art.commit(self)

static func _scaled(shares: Array[Vector2]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for share in shares:
		points.append(Vector2(share.x * HALF_WIDTH, -share.y * HEIGHT))
	return points

## A squat rock sitting on its ground point, with a shaded lower right.
func _draw_boulder(canvas: Node2D, radius: float) -> void:
	canvas.draw_colored_polygon(FlatProps.octagon(Vector2(radius * 0.2, 2.0), radius * 1.1, radius * 0.25), UiPalette.SHADOW)
	canvas.draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -radius * 0.6), radius, radius * 0.65), ROCK)
	canvas.draw_colored_polygon(FlatProps.octagon(Vector2(radius * 0.3, -radius * 0.4), radius * 0.6, radius * 0.4), ROCK_SHADE)

## The HILL CLIMB board on two posts, its lettering on top.
func _draw_board(canvas: Node2D) -> void:
	var board := Rect2(-BOARD_SIZE.x * 0.5, -BOARD_POST_HEIGHT - BOARD_SIZE.y, BOARD_SIZE.x, BOARD_SIZE.y)
	for post_x: float in [board.position.x + 30.0, board.end.x - 38.0]:
		canvas.draw_rect(Rect2(post_x, board.end.y, 8.0, BOARD_POST_HEIGHT), UiPalette.POST_GREY)
	canvas.draw_rect(board, BOARD)
	canvas.draw_rect(Rect2(board.end.x - 12.0, board.position.y, 12.0, board.size.y), BOARD.darkened(0.2))
	canvas.draw_string(ThemeDB.fallback_font, board.position + Vector2(0.0, 46.0), "HILL CLIMB",
			HORIZONTAL_ALIGNMENT_CENTER, board.size.x - 12.0, 34, UiPalette.DANGER_RED)
