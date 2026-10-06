@tool
class_name RallyStage
extends Node2D
## The rally stage on the world map: a winding dirt road that climbs over two
## grassy hills (a sunlit crest across the road on each hilltop, a shaded
## downslope past it), a RALLY board by the start line, orange stage flags, hay
## bales on the outside of the bends, and a checkered finish.
##
## Drawn in `_draw()` from a few numbers like DragStrip, as one TriangleBatch.
## The sign posts and hay bales are solid. @tool so it's visible in the editor.

@export var length: float = 2400.0
@export var road_width: float = 200.0
## How far the road swings side to side, and over what distance.
@export var bend_amplitude: float = 110.0
@export var bend_length: float = 1400.0
@export var start_x: float = -850.0
@export var finish_x: float = 1050.0
## Where the road crosses a hilltop.
@export var hill_xs: PackedFloat32Array = PackedFloat32Array([-250.0, 520.0])

const DIRT := UiPalette.SURFACE_BASE
const CREST := UiPalette.SURFACE_LIGHT
const DOWNSLOPE := UiPalette.SURFACE_DARK
const HILL := Color(0.45, 0.52, 0.31)
const HILL_SHADE := Color(0.38, 0.44, 0.26)
const MARKING := Color(0.88, 0.86, 0.78)
const PENNANT := Color(0.85, 0.45, 0.12)
const HAY := Color(0.78, 0.66, 0.36)
const HAY_SHADE := Color(0.66, 0.54, 0.28)
const SIGN_BOARD := Color(0.85, 0.66, 0.12)

const HILL_RADIUS := Vector2(300.0, 190.0)
const CREST_HALF_LENGTH := 50.0
const DOWNSLOPE_LENGTH := 130.0
const SAMPLE_STEP := 50.0
const FINISH_ROWS := 4
const BALE_SIZE := Vector2(90.0, 40.0)
const FLAG_XS := [-500.0, 150.0, 800.0]
const SIGN_SIZE := Vector2(170.0, 56.0)
const SIGN_POST_HEIGHT := 70.0

var _art := TriangleBatch.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for rect in _solid_rects():
		RoundedRectShape.add_solid(self, rect)

func _draw() -> void:
	_art.clear()
	for hill_x in hill_xs:
		_draw_hill(Vector2(hill_x, centre_y(hill_x)))
	_art.draw_colored_polygon(_road_band(-length * 0.5, length * 0.5), DIRT)
	for hill_x in hill_xs:
		_art.draw_colored_polygon(_road_band(hill_x - CREST_HALF_LENGTH, hill_x + CREST_HALF_LENGTH), CREST)
		_art.draw_colored_polygon(_road_band(hill_x + CREST_HALF_LENGTH, hill_x + CREST_HALF_LENGTH + DOWNSLOPE_LENGTH), DOWNSLOPE)
	_art.draw_colored_polygon(_road_band(start_x - 8.0, start_x + 8.0), MARKING)
	_draw_finish()
	for base in _flag_bases():
		_draw_flag(base)
	for rect in _bale_rects():
		_art.draw_rect(rect, HAY)
		_art.draw_rect(Rect2(rect.end.x - 14.0, rect.position.y, 14.0, rect.size.y), HAY_SHADE)
	FlatProps.draw_tire_stack(_art, _tire_stack_base(), 3)
	_draw_sign()
	_art.commit(self)
	_art.clear()
	var board := _sign_board_rect()
	draw_string(ThemeDB.fallback_font, board.position + Vector2(0.0, 40.0), "RALLY",
			HORIZONTAL_ALIGNMENT_CENTER, board.size.x - 12.0, 36, UiPalette.DANGER_RED)

## The road's centre line at local x.
func centre_y(x: float) -> float:
	return bend_amplitude * sin(TAU * x / bend_length)

## The stretch of road between two x's, full width, following the bends.
func _road_band(from_x: float, to_x: float) -> PackedVector2Array:
	var near := PackedVector2Array()
	var far := PackedVector2Array()
	var steps := maxi(1, int(ceilf((to_x - from_x) / SAMPLE_STEP)))
	for i in steps + 1:
		var x := lerpf(from_x, to_x, float(i) / float(steps))
		near.append(Vector2(x, centre_y(x) - road_width * 0.5))
		far.append(Vector2(x, centre_y(x) + road_width * 0.5))
	far.reverse()
	near.append_array(far)
	return near

## A grassy mound the road runs over, with its lower-right side in shade.
func _draw_hill(center: Vector2) -> void:
	_art.draw_colored_polygon(FlatProps.octagon(center, HILL_RADIUS.x, HILL_RADIUS.y), HILL)
	_art.draw_colored_polygon(PackedVector2Array([
		center + Vector2(HILL_RADIUS.x * 0.92, -HILL_RADIUS.y * 0.38),
		center + Vector2(HILL_RADIUS.x * 0.92, HILL_RADIUS.y * 0.38),
		center + Vector2(HILL_RADIUS.x * 0.38, HILL_RADIUS.y * 0.92),
		center + Vector2(-HILL_RADIUS.x * 0.38, HILL_RADIUS.y * 0.92),
		center + Vector2(0.0, HILL_RADIUS.y * 0.5),
	]), HILL_SHADE)

func _draw_finish() -> void:
	var cell := Vector2(road_width / FINISH_ROWS, road_width / FINISH_ROWS)
	var top := centre_y(finish_x) - road_width * 0.5
	for row in FINISH_ROWS:
		for column in 2:
			var light := (row + column) % 2 == 0
			_art.draw_rect(Rect2(finish_x - cell.x + column * cell.x, top + row * cell.y, cell.x, cell.y),
					MARKING if light else UiPalette.INK)

func _flag_bases() -> Array[Vector2]:
	var bases: Array[Vector2] = []
	for x: float in FLAG_XS:
		bases.append(Vector2(x, centre_y(x) - road_width * 0.5 - 30.0))
	return bases

func _tire_stack_base() -> Vector2:
	return Vector2(finish_x + 90.0, centre_y(finish_x) + road_width * 0.5 + 40.0)

func _draw_flag(base: Vector2) -> void:
	var pole_top := base + Vector2(-4.0, -70.0)
	_art.draw_rect(Rect2(pole_top.x, pole_top.y, 8.0, 70.0), UiPalette.POST_GREY)
	_art.draw_colored_polygon(PackedVector2Array([
		pole_top + Vector2(8.0, 0.0), pole_top + Vector2(46.0, 12.0), pole_top + Vector2(8.0, 26.0),
	]), PENNANT)

## The RALLY board on two posts (its lettering is drawn after the batch), just behind the start line on the far verge.
func _draw_sign() -> void:
	var board := _sign_board_rect()
	for post_x: float in [board.position.x + 22.0, board.end.x - 30.0]:
		_art.draw_rect(Rect2(post_x, board.end.y, 8.0, SIGN_POST_HEIGHT), UiPalette.POST_GREY)
	_art.draw_rect(board, SIGN_BOARD)
	_art.draw_rect(Rect2(board.end.x - 12.0, board.position.y, 12.0, board.size.y), SIGN_BOARD.darkened(0.2))

func _sign_board_rect() -> Rect2:
	var post_base := Vector2(start_x - 140.0, centre_y(start_x - 140.0) - road_width * 0.5 - 20.0)
	return Rect2(post_base.x - SIGN_SIZE.x * 0.5, post_base.y - SIGN_POST_HEIGHT - SIGN_SIZE.y, SIGN_SIZE.x, SIGN_SIZE.y)

## Bales sit on the outside of each bend: below the road where it swings
## down, above it where it swings up.
func _bale_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var x := -bend_length * 0.75
	while x < length * 0.5:
		if x > start_x + 100.0 and x < finish_x - 100.0:
			var swing := signf(centre_y(x))
			var y := centre_y(x) + swing * (road_width * 0.5 + 30.0 + BALE_SIZE.y * 0.5)
			rects.append(Rect2(Vector2(x, y) - BALE_SIZE * 0.5, BALE_SIZE))
		x += bend_length * 0.5
	return rects

func _solid_rects() -> Array[Rect2]:
	var rects := _bale_rects()
	var board := _sign_board_rect()
	rects.append(Rect2(board.position.x, board.end.y + SIGN_POST_HEIGHT - 16.0, board.size.x, 16.0))
	for base in _flag_bases():
		rects.append(Rect2(base.x - 10.0, base.y - 12.0, 20.0, 14.0))
	var tires := _tire_stack_base()
	rects.append(Rect2(tires.x - 18.0, tires.y - 14.0, 36.0, 20.0))
	return rects
