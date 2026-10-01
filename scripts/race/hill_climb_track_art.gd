@tool
class_name HillClimbTrackArt
extends Node2D
## The hill climb the cars are drawn on: a five-lane gravel road up the parent
## HillClimbTrack's slope, a scrubby rock bank behind it with height boards
## every HEIGHT_BOARD_STEP metres, a grey cliff falling away in front, a start
## line, the checkered finish on the summit and a summit flag.
##
## Lane geometry matches RallyTrackArt, and every edge follows
## HillClimbTrack.surface_offset_at() through surface_band().

@export var lane_count := 5
@export var lane_height := 200.0
@export var top_lane_y := 0.0
@export var apron := 100.0
@export var finish_x := 5400.0
@export var start_x := 0.0
@export var finish_cell := 48.0
@export var finish_cells := 3

const GRAVEL := Color(0.52, 0.47, 0.40)
const RUT := Color(0.44, 0.40, 0.34)
const BANK := Color(0.47, 0.49, 0.36)
const CLIFF := Color(0.45, 0.43, 0.41)
const CLIFF_SHADE := Color(0.37, 0.35, 0.34)
const SNOW := Color(0.88, 0.89, 0.90)
const MARKING := Color(0.93, 0.92, 0.86)
const BOARD := Color(0.85, 0.66, 0.12)
const SUMMIT_FLAG := UiPalette.DANGER_RED

const BANK_DEPTH := 240.0
const CLIFF_SHADE_DEPTH := 50.0
const CLIFF_DEPTH := 3200.0
const RUT_WIDTH := 10.0
const MARKING_WIDTH := 18.0
## Screen pixels per metre on the height boards.
const PIXELS_PER_METRE := 10.0
const HEIGHT_BOARD_STEP := 50
const BOARD_SIZE := Vector2(200.0, 84.0)
const POST_HEIGHT := 110.0
const SUMMIT_POLE_HEIGHT := 260.0

var _art := TriangleBatch.new()

func _draw() -> void:
	var track := get_parent() as HillClimbTrack
	if track == null:
		return
	var top := top_lane_y - lane_height * 0.5 - apron
	var bottom := top_lane_y + lane_height * float(lane_count - 1) + lane_height * 0.5 + apron
	_art.clear()
	_art.draw_colored_polygon(track.surface_band(top - BANK_DEPTH, top), BANK)
	_draw_summit_snow(track, top)
	_art.draw_colored_polygon(track.surface_band(top, bottom), GRAVEL)
	for i in range(1, lane_count):
		var y := top_lane_y - lane_height * 0.5 + lane_height * float(i)
		_art.draw_colored_polygon(track.surface_band(y - RUT_WIDTH * 0.5, y + RUT_WIDTH * 0.5), RUT)
	_art.draw_colored_polygon(track.surface_band(bottom, bottom + CLIFF_SHADE_DEPTH), CLIFF_SHADE)
	_art.draw_colored_polygon(track.surface_band(bottom + CLIFF_SHADE_DEPTH, bottom + CLIFF_DEPTH), CLIFF)
	_art.draw_rect(Rect2(start_x - MARKING_WIDTH * 0.5, top, MARKING_WIDTH, bottom - top), MARKING)
	_draw_finish(track, top, bottom)
	var boards := _height_boards(track, top - BANK_DEPTH * 0.5)
	for board in boards:
		_draw_board(board["rect"])
	_draw_summit_flag(track, top - BANK_DEPTH * 0.5)
	_art.commit(self)
	_art.clear()
	for board in boards:
		var rect: Rect2 = board["rect"]
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 62.0), board["text"],
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12.0, 56, UiPalette.INK)

## The bank turns to snow over the crest.
func _draw_summit_snow(track: HillClimbTrack, top: float) -> void:
	var from_x := track.summit_x - track.crest_length
	var points := PackedVector2Array()
	var x := from_x
	while x <= track.right:
		points.append(Vector2(x, top - BANK_DEPTH + track.surface_offset_at(x)))
		x += RallyTrack.COLUMN_WIDTH
	points.append(Vector2(track.right, top + track.surface_offset_at(track.right) - BANK_DEPTH * 0.45))
	points.append(Vector2(from_x + 120.0, top + track.surface_offset_at(from_x + 120.0) - BANK_DEPTH * 0.45))
	_art.draw_colored_polygon(points, SNOW)

## On the flat summit, so its cells are plain squares.
func _draw_finish(track: HillClimbTrack, top: float, bottom: float) -> void:
	var lift := track.surface_offset_at(finish_x)
	var rows := maxi(2, int(round((bottom - top) / finish_cell)))
	var cell := Vector2(finish_cell, (bottom - top) / float(rows))
	var origin := Vector2(finish_x - cell.x * float(finish_cells) * 0.5, top + lift)
	for row in rows:
		for column in finish_cells:
			var light := (row + column) % 2 == 0
			_art.draw_rect(Rect2(origin + cell * Vector2(float(column), float(row)), cell), MARKING if light else UiPalette.INK)

## A board on the bank wherever the road passes every HEIGHT_BOARD_STEP
## metres of climb: {"rect", "text"}.
func _height_boards(track: HillClimbTrack, base_y: float) -> Array[Dictionary]:
	var boards: Array[Dictionary] = []
	var metres := HEIGHT_BOARD_STEP
	while metres * PIXELS_PER_METRE < track.summit_height() - 100.0:
		var x := track.x_at_height(metres * PIXELS_PER_METRE)
		var post_base := Vector2(x, base_y + track.surface_offset_at(x))
		boards.append({
			"rect": Rect2(post_base.x - BOARD_SIZE.x * 0.5, post_base.y - POST_HEIGHT - BOARD_SIZE.y, BOARD_SIZE.x, BOARD_SIZE.y),
			"text": "%dm" % metres,
		})
		metres += HEIGHT_BOARD_STEP
	return boards

func _draw_board(rect: Rect2) -> void:
	_art.draw_rect(Rect2(rect.get_center().x - 5.0, rect.end.y, 10.0, POST_HEIGHT), UiPalette.POST_GREY)
	_art.draw_rect(rect, BOARD)
	_art.draw_rect(Rect2(rect.end.x - 12.0, rect.position.y, 12.0, rect.size.y), BOARD.darkened(0.2))

## A tall pole with a red pennant just past the summit finish.
func _draw_summit_flag(track: HillClimbTrack, base_y: float) -> void:
	var x := finish_x + 260.0
	var base := Vector2(x, base_y + track.surface_offset_at(x))
	var pole_top := base - Vector2(0.0, SUMMIT_POLE_HEIGHT)
	_art.draw_rect(Rect2(pole_top.x - 5.0, pole_top.y, 10.0, SUMMIT_POLE_HEIGHT), UiPalette.STEEL_SHADE)
	_art.draw_colored_polygon(PackedVector2Array([
		pole_top + Vector2(5.0, 0.0), pole_top + Vector2(110.0, 26.0), pole_top + Vector2(5.0, 56.0),
	]), SUMMIT_FLAG)
