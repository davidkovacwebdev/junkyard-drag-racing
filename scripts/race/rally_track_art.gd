@tool
class_name RallyTrackArt
extends Node2D
## The rally stage the cars are drawn on: a five-lane dirt road rolling over the
## parent RallyTrack's hills, a grass verge behind it with stage marker flags, a
## green hillside falling away in front with a few hay bales on its lip, worn
## ruts between the lanes, a start line and the checkered finish. Around it all
## lies open countryside (meadow, ploughed fields, trees, a pond) so the race
## camera's widest view never shows the empty background.
##
## Lane geometry matches DragTrackArt (lanes `lane_height` apart, first lane's
## centre at `top_lane_y`), and every edge follows RallyTrack.surface_offset_at()
## so the painted road sits exactly on the collision the cars drive on.

@export var lane_count := 5
@export var lane_height := 200.0
@export var top_lane_y := 0.0
@export var apron := 100.0
@export var finish_x := 5400.0
@export var start_x := 0.0
@export var finish_cell := 48.0
@export var finish_cells := 3
@export var art_seed := 11
## Countryside laid out past the track's ends and edges.
@export var countryside_margin := Vector2(3000.0, 2000.0)

const DIRT := UiPalette.SURFACE_BASE
const RUT := UiPalette.SURFACE_SHADE
const GRAVEL_PATCH := UiPalette.SURFACE_DARK
const VERGE := Color(0.45, 0.52, 0.31)
const HILLSIDE := Color(0.38, 0.46, 0.27)
const HILLSIDE_SHADE := Color(0.31, 0.38, 0.22)
const MARKING := Color(0.93, 0.92, 0.86)
const FINISH_DARK := UiPalette.INK
const PENNANT := Color(0.85, 0.45, 0.12)
const HAY := Color(0.78, 0.66, 0.36)
const HAY_SHADE := Color(0.66, 0.54, 0.28)
const MEADOW := Color(0.50, 0.56, 0.33)
const PLOUGHED := Color(0.52, 0.44, 0.30)
const PLOUGHED_SHADE := Color(0.44, 0.37, 0.25)
const TRUNK := Color(0.40, 0.30, 0.20)
const CANOPY := Color(0.30, 0.42, 0.24)
const CANOPY_SHADE := Color(0.24, 0.34, 0.19)
const POND := Color(0.36, 0.52, 0.58)
const POND_SHADE := Color(0.30, 0.44, 0.50)

const VERGE_DEPTH := 140.0
const HILLSIDE_DEPTH := 1400.0
const HILLSIDE_SHADE_DEPTH := 40.0
const RUT_WIDTH := 10.0
const MARKING_WIDTH := 18.0
const FLAG_SPACING := 900.0
const BALE_SPACING := 1300.0
const PATCH_COUNT := 6
const FIELD_COUNT := 5
const TREE_COUNT := 9

var _art := TriangleBatch.new()

func _draw() -> void:
	var track := get_parent() as RallyTrack
	if track == null:
		return
	var top := top_lane_y - lane_height * 0.5 - apron
	var bottom := top_lane_y + lane_height * float(lane_count - 1) + lane_height * 0.5 + apron
	var rng := RandomNumberGenerator.new()
	rng.seed = art_seed
	_art.clear()
	_draw_countryside(track, rng, top, bottom)
	_draw_band(track, top - VERGE_DEPTH, top, VERGE)
	_draw_band(track, top, bottom, DIRT)
	_draw_gravel_patches(track, rng, top, bottom)
	for i in range(1, lane_count):
		var y := top_lane_y - lane_height * 0.5 + lane_height * float(i)
		_draw_band(track, y - RUT_WIDTH * 0.5, y + RUT_WIDTH * 0.5, RUT)
	_draw_band(track, bottom, bottom + HILLSIDE_SHADE_DEPTH, HILLSIDE_SHADE)
	_draw_band(track, bottom + HILLSIDE_SHADE_DEPTH, bottom + HILLSIDE_DEPTH, HILLSIDE)
	_art.draw_rect(Rect2(start_x - MARKING_WIDTH * 0.5, top, MARKING_WIDTH, bottom - top), MARKING)
	_draw_finish(top, bottom)
	_draw_flags(track, top - VERGE_DEPTH * 0.5)
	_draw_bales(track, bottom + 6.0)
	_art.commit(self)
	_art.clear()

## A band bent onto the road, carried on flat past both ends of the track so
## the road runs off into the countryside instead of stopping short.
func _draw_band(track: RallyTrack, band_top: float, band_bottom: float, color: Color) -> void:
	_art.draw_colored_polygon(track.surface_band(band_top, band_bottom), color)
	var height := band_bottom - band_top
	_art.draw_rect(Rect2(track.left - countryside_margin.x, band_top, countryside_margin.x, height), color)
	_art.draw_rect(Rect2(track.right, band_top, countryside_margin.x, height), color)

## The finish sits on the flat run-out, so its cells are plain squares.
func _draw_finish(top: float, bottom: float) -> void:
	var rows := maxi(2, int(round((bottom - top) / finish_cell)))
	var cell := Vector2(finish_cell, (bottom - top) / float(rows))
	var origin := Vector2(finish_x - cell.x * float(finish_cells) * 0.5, top)
	for row in rows:
		for column in finish_cells:
			var light := (row + column) % 2 == 0
			_art.draw_rect(Rect2(origin + cell * Vector2(float(column), float(row)), cell), MARKING if light else FINISH_DARK)

## A few big loose-gravel patches, tilted to the slope they sit on.
func _draw_gravel_patches(track: RallyTrack, rng: RandomNumberGenerator, top: float, bottom: float) -> void:
	for i in PATCH_COUNT:
		var x := rng.randf_range(start_x + 400.0, finish_x - 300.0)
		var y := rng.randf_range(top + 60.0, bottom - 60.0) + track.surface_offset_at(x)
		var half := Vector2(rng.randf_range(90.0, 170.0), rng.randf_range(24.0, 40.0))
		var rise := (track.surface_offset_at(x + half.x) - track.surface_offset_at(x - half.x)) * 0.5
		_art.draw_colored_polygon(PackedVector2Array([
			Vector2(x - half.x, y - half.y - rise), Vector2(x + half.x * 0.8, y - half.y + rise),
			Vector2(x + half.x, y + half.y + rise), Vector2(x - half.x * 0.7, y + half.y - rise),
		]), GRAVEL_PATCH)

## Stage marker poles on the far verge, each with one orange pennant.
func _draw_flags(track: RallyTrack, base_y: float) -> void:
	var x := start_x + 300.0
	while x < finish_x:
		var base := Vector2(x, base_y + track.surface_offset_at(x))
		var pole_top := base + Vector2(0.0, -90.0)
		_art.draw_rect(Rect2(pole_top.x - 4.0, pole_top.y, 8.0, 90.0), UiPalette.POST_GREY)
		_art.draw_colored_polygon(PackedVector2Array([
			pole_top + Vector2(4.0, 0.0), pole_top + Vector2(48.0, 14.0), pole_top + Vector2(4.0, 30.0),
		]), PENNANT)
		x += FLAG_SPACING

## Hay bales on the near lip of the road, where a car would go off the edge.
func _draw_bales(track: RallyTrack, base_y: float) -> void:
	var x := start_x + 800.0
	while x < finish_x - 200.0:
		var y := base_y + track.surface_offset_at(x)
		_art.draw_rect(Rect2(x - 50.0, y - 10.0, 100.0, 44.0), HAY)
		_art.draw_rect(Rect2(x + 34.0, y - 10.0, 16.0, 44.0), HAY_SHADE)
		x += BALE_SPACING

## --- Countryside ----------------------------------------------------------------

## Meadow under everything, then a few ploughed fields, trees and one pond on
## the far side of the verge and down in the valley below the hillside.
func _draw_countryside(track: RallyTrack, rng: RandomNumberGenerator, top: float, bottom: float) -> void:
	var far_top := top - VERGE_DEPTH - countryside_margin.y
	var far_bottom := bottom + HILLSIDE_DEPTH + countryside_margin.y
	_art.draw_rect(Rect2(track.left - countryside_margin.x, far_top,
			track.right - track.left + countryside_margin.x * 2.0, far_bottom - far_top), MEADOW)
	var wide := Vector2(track.left - countryside_margin.x * 0.8, track.right + countryside_margin.x * 0.8)
	var behind := Vector2(far_top + 300.0, top - VERGE_DEPTH - 400.0)
	var valley := Vector2(bottom + HILLSIDE_DEPTH + 300.0, far_bottom - 300.0)

	for i in FIELD_COUNT:
		var band := behind if i % 2 == 0 else valley
		_draw_ploughed_field(Vector2(rng.randf_range(wide.x, wide.y), rng.randf_range(band.x, band.y)), rng)
	_draw_pond(Vector2(rng.randf_range(wide.x, wide.y), rng.randf_range(valley.x, valley.y)))
	for i in TREE_COUNT:
		var band := behind if i % 3 != 2 else valley
		_draw_tree(Vector2(rng.randf_range(wide.x, wide.y), rng.randf_range(band.x, band.y)), rng.randf_range(0.8, 1.3))

## A big tilted patch of bare earth with one shade strip along its bottom.
func _draw_ploughed_field(center: Vector2, rng: RandomNumberGenerator) -> void:
	var half := Vector2(rng.randf_range(500.0, 900.0), rng.randf_range(180.0, 300.0))
	var skew := rng.randf_range(-60.0, 60.0)
	var corners := PackedVector2Array([
		center + Vector2(-half.x + skew, -half.y), center + Vector2(half.x + skew, -half.y + 20.0),
		center + Vector2(half.x - skew, half.y), center + Vector2(-half.x - skew, half.y - 20.0),
	])
	_art.draw_colored_polygon(corners, PLOUGHED)
	_art.draw_colored_polygon(PackedVector2Array([
		corners[3].lerp(corners[0], 0.2), corners[2].lerp(corners[1], 0.2), corners[2], corners[3],
	]), PLOUGHED_SHADE)

## Trunk, round canopy and a shade wedge on its lower right.
func _draw_tree(base: Vector2, size: float) -> void:
	_art.draw_rect(Rect2(base.x - 14.0 * size, base.y - 80.0 * size, 28.0 * size, 80.0 * size), TRUNK)
	var crown := base + Vector2(0.0, -150.0 * size)
	_art.draw_colored_polygon(FlatProps.octagon(crown, 100.0 * size, 90.0 * size), CANOPY)
	_art.draw_colored_polygon(FlatProps.octagon(crown + Vector2(30.0, 28.0) * size, 60.0 * size, 52.0 * size), CANOPY_SHADE)

func _draw_pond(center: Vector2) -> void:
	_art.draw_colored_polygon(FlatProps.octagon(center, 420.0, 170.0), POND)
	_art.draw_colored_polygon(FlatProps.octagon(center + Vector2(60.0, 50.0), 260.0, 80.0), POND_SHADE)
