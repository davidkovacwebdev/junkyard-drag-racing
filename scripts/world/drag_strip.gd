@tool
class_name DragStrip
extends Node2D
## The drag strip on the world map, cut from the same flat polygons as the rest
## of the world: a patched two-lane strip on a gravel apron, rubber laid down
## off the burnout box, a staging light tree, a checkered finish, painted
## concrete barriers, a tyre wall at the shutdown end, wooden bleachers with a
## sparse crowd, a scoreboard, and tyre/drum clutter in the pits.
##
## Everything is drawn in `_draw()` from a few numbers and a fixed seed, so it
## looks the same every launch. Structures you'd crash into (bleachers, tyre
## wall, pit clutter) get a solid footprint at runtime. @tool so it's visible
## in the 2D editor too.

@export var length: float = 2800.0
@export var width: float = 360.0
## Local x of the staging/start line and the checkered finish line.
@export var start_x: float = -1150.0
@export var finish_x: float = 1200.0
@export var art_seed: int = 7311

const ASPHALT := Color("4a6e64")
const BURNOUT := Color(0.24, 0.33, 0.31)
const PATCH := Color(0.33, 0.47, 0.43)
const CRACK := Color(0.21, 0.3, 0.28)
const RUBBER := Color(0.1, 0.1, 0.1)
const LINE := Color(0.95, 0.93, 0.68, 0.5)
const EDGE_LINE := Color(0.9, 0.92, 0.87, 0.55)
const START_LINE := Color(0.88, 0.86, 0.78)
const CHECKER_LIGHT := Color(0.86, 0.84, 0.78)
const APRON := Color(0.52, 0.49, 0.42)
const APRON_DARK := Color(0.46, 0.43, 0.37)
const CONCRETE := Color(0.62, 0.61, 0.57)
const CONCRETE_TOP := Color(0.72, 0.71, 0.66)
const CONCRETE_SHADE := Color(0.52, 0.51, 0.48)
const PAINT_RED := Color(0.6, 0.2, 0.17)
const PAINT_RED_TOP := Color(0.68, 0.26, 0.21)
const WOOD_PLANK := Color(0.62, 0.48, 0.32)
const WOOD_RISER := Color(0.46, 0.34, 0.22)
const WOOD_SHADE := Color(0.4, 0.29, 0.19)
const LIGHT_AMBER := Color(0.85, 0.6, 0.12)
const LIGHT_GREEN := Color(0.35, 0.62, 0.3)
const CROWD_SHIRTS := [
	Color(0.55, 0.22, 0.18), Color(0.3, 0.4, 0.52), Color(0.62, 0.55, 0.3),
	Color(0.35, 0.45, 0.32), Color(0.5, 0.46, 0.42), Color(0.42, 0.3, 0.45),
]
const CROWD_SKIN := [Color(0.8, 0.64, 0.5), Color(0.62, 0.45, 0.32), Color(0.45, 0.32, 0.24)]
const DRUM_COLORS := [Color(0.3, 0.4, 0.52), Color(0.55, 0.3, 0.18), Color(0.4, 0.45, 0.3)]

const APRON_MARGIN := 50.0
const BURNOUT_LENGTH := 260.0
const BARRIER_SEGMENT := 100.0
const BARRIER_GAP := 8.0
const BARRIER_FACE_H := 14.0
const BARRIER_TOP_H := 7.0
const TIRE_SPACING := 30.0
const STAND_ROWS := 4
const STAND_ROW_DEPTH := 26.0
const STAND_RISER_H := 16.0
const STAND_PLANK_H := 10.0

var _half_len: float
var _half_w: float

func _ready() -> void:
	_update_extent()
	if Engine.is_editor_hint():
		return
	for rect in _solid_rects():
		_add_solid(rect)

func _draw() -> void:
	_update_extent()
	var rng := RandomNumberGenerator.new()
	rng.seed = art_seed
	_draw_ground(rng)
	_draw_markings()
	_draw_grandstand(rng)
	_draw_scoreboard()
	_draw_barrier_row(-_half_w - 6.0)
	_draw_timing_pole(Vector2(finish_x, -_half_w - 14.0))
	_draw_tire_wall()
	_draw_light_tree(Vector2(start_x - 120.0, 0.0))
	_draw_barrier_row(_half_w + 26.0)
	_draw_timing_pole(Vector2(finish_x, _half_w + 30.0))
	_draw_pit_clutter(rng)

func _update_extent() -> void:
	_half_len = length / 2.0
	_half_w = width / 2.0

# --- Ground --------------------------------------------------------------------

func _draw_ground(rng: RandomNumberGenerator) -> void:
	var apron_rect := Rect2(-_half_len - APRON_MARGIN, -_half_w - APRON_MARGIN,
			length + APRON_MARGIN * 2.0, width + APRON_MARGIN * 2.0)
	draw_colored_polygon(_jittered_rect(apron_rect, 120.0, 8.0, rng), APRON)
	for i in 10:
		var center := Vector2(rng.randf_range(-_half_len, _half_len),
				(_half_w + APRON_MARGIN * 0.5) * (1.0 if rng.randf() < 0.5 else -1.0))
		draw_colored_polygon(_blob(center, rng.randf_range(60.0, 140.0), rng.randf_range(14.0, 26.0), rng), APRON_DARK)

	draw_colored_polygon(_jittered_rect(Rect2(-_half_len, -_half_w, length, width), 140.0, 3.0, rng), ASPHALT)
	draw_colored_polygon(_jittered_rect(Rect2(start_x - BURNOUT_LENGTH, -_half_w + 4.0, BURNOUT_LENGTH, width - 8.0), 60.0, 4.0, rng), BURNOUT)

	for i in 7:
		var center := Vector2(rng.randf_range(start_x + 200.0, _half_len - 80.0), rng.randf_range(-_half_w + 40.0, _half_w - 40.0))
		draw_colored_polygon(_rotated_quad(center, Vector2(rng.randf_range(50.0, 120.0), rng.randf_range(30.0, 60.0)), rng.randf_range(-0.08, 0.08)), PATCH)
	for i in 9:
		var crack_start := Vector2(rng.randf_range(-_half_len + 60.0, _half_len - 60.0), rng.randf_range(-_half_w + 20.0, _half_w - 20.0))
		_draw_crack(crack_start, rng)

	for lane_y: float in [-_half_w * 0.5, _half_w * 0.5]:
		for tire_offset: float in [-28.0, 28.0]:
			_draw_rubber_streak(lane_y + tire_offset, rng)

## Zigzag of thin flat slivers — a crack, not a stroked line.
func _draw_crack(from: Vector2, rng: RandomNumberGenerator) -> void:
	var point := from
	var heading := rng.randf_range(0.0, TAU)
	for i in rng.randi_range(3, 5):
		heading += rng.randf_range(-0.9, 0.9)
		var next := point + Vector2.from_angle(heading) * rng.randf_range(14.0, 30.0)
		draw_colored_polygon(FlatProps.sliver(point, next, 2.5), CRACK)
		point = next

## Rubber laid down off the burnout box, heavy at the line and wearing away
## down the track.
func _draw_rubber_streak(y: float, rng: RandomNumberGenerator) -> void:
	var streak_end := start_x + 900.0
	var step := 50.0
	var x := start_x - BURNOUT_LENGTH + 20.0
	var previous := Vector2(x, y)
	while x < streak_end:
		x += step
		var t := inverse_lerp(start_x, streak_end, x)
		var alpha := 0.5 if t < 0.0 else 0.5 * pow(1.0 - t, 1.6)
		var next := Vector2(x, y + rng.randf_range(-2.0, 2.0))
		draw_colored_polygon(FlatProps.sliver(previous, next, 9.0), Color(RUBBER, alpha))
		previous = next

func _draw_markings() -> void:
	for edge_y: float in [-_half_w + 10.0, _half_w - 14.0]:
		draw_rect(Rect2(-_half_len + 12.0, edge_y, length - 24.0, 4.0), EDGE_LINE)

	var x := start_x + 40.0
	while x < _half_len - 40.0:
		draw_rect(Rect2(x, -3.0, minf(64.0, _half_len - 40.0 - x), 6.0), LINE)
		x += 120.0

	draw_rect(Rect2(start_x - 6.0, -_half_w + 6.0, 12.0, width - 12.0), START_LINE)
	for lane_y: float in [-_half_w * 0.5, _half_w * 0.5]:
		for tick in 2:
			draw_rect(Rect2(start_x - 40.0 - tick * 22.0, lane_y - 30.0, 6.0, 60.0), START_LINE)

	var rows := 14
	var cell := (width - 12.0) / rows
	for r in rows:
		for c in 2:
			var color := CHECKER_LIGHT if (r + c) % 2 == 0 else UiPalette.INK
			draw_rect(Rect2(finish_x - cell + c * cell, -_half_w + 6.0 + r * cell, cell, cell), color)

# --- Structures ----------------------------------------------------------------

func _barrier_range() -> Vector2:
	return Vector2(start_x + 60.0, _half_len - 60.0)

## A run of jersey barriers, alternating bare concrete and faded red paint.
## `base_y` is the bottom of the front face.
func _draw_barrier_row(base_y: float) -> void:
	var span := _barrier_range()
	var x := span.x
	var index := 0
	while x < span.y:
		var x_end := minf(x + BARRIER_SEGMENT, span.y)
		var painted := index % 2 == 1
		var face_top := base_y - BARRIER_FACE_H
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 3.0, face_top - BARRIER_TOP_H), Vector2(x_end - 3.0, face_top - BARRIER_TOP_H),
			Vector2(x_end, face_top), Vector2(x, face_top),
		]), PAINT_RED_TOP if painted else CONCRETE_TOP)
		draw_rect(Rect2(x, face_top, x_end - x, BARRIER_FACE_H), PAINT_RED if painted else CONCRETE)
		draw_rect(Rect2(x_end - 8.0, face_top, 8.0, BARRIER_FACE_H), CONCRETE_SHADE)
		draw_rect(Rect2(x, base_y - 3.0, x_end - x, 3.0), CONCRETE_SHADE)
		x = x_end + BARRIER_GAP
		index += 1

## Stacked tyres across the shutdown end, so an overshooting car has
## something softer than a wall to hit.
func _draw_tire_wall() -> void:
	var x := _half_len + 26.0
	var y := -_half_w - 10.0
	var index := 0
	while y <= _half_w + 10.0:
		FlatProps.draw_tire_stack(self, Vector2(x + (6.0 if index % 2 == 1 else 0.0), y), 2 + index % 2)
		y += TIRE_SPACING
		index += 1

func _grandstand_rect() -> Rect2:
	var front_y := -_half_w - 40.0
	var depth := STAND_ROWS * STAND_ROW_DEPTH + STAND_PLANK_H
	return Rect2(finish_x - 720.0, front_y - depth, 760.0, depth)

## Wooden bleachers facing the finish, drawn back row first so each row sits in
## front of the one behind it, with a sparse crowd and a railing along the top.
func _draw_grandstand(rng: RandomNumberGenerator) -> void:
	var stand := _grandstand_rect()
	var front_y := stand.end.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(stand.position.x + 6.0, front_y - 20.0), Vector2(stand.end.x, front_y - 20.0),
		Vector2(stand.end.x + 10.0, front_y + 8.0), Vector2(stand.position.x + 16.0, front_y + 8.0),
	]), UiPalette.SHADOW)

	var rail_y := stand.position.y - 18.0
	for post_x in range(int(stand.position.x) + 6, int(stand.end.x), 95):
		draw_rect(Rect2(post_x, rail_y, 5.0, 20.0), UiPalette.POST_GREY)
	draw_rect(Rect2(stand.position.x, rail_y, stand.size.x, 4.0), UiPalette.POST_GREY.lightened(0.15))

	for row in range(STAND_ROWS - 1, -1, -1):
		var riser_bottom := front_y - row * STAND_ROW_DEPTH
		var riser_top := riser_bottom - STAND_RISER_H
		draw_rect(Rect2(stand.position.x, riser_top - STAND_PLANK_H, stand.size.x, STAND_PLANK_H), WOOD_PLANK)
		draw_rect(Rect2(stand.position.x, riser_top, stand.size.x, STAND_RISER_H), WOOD_RISER)
		draw_rect(Rect2(stand.end.x - 12.0, riser_top - STAND_PLANK_H, 12.0, STAND_RISER_H + STAND_PLANK_H), WOOD_SHADE)
		for seam_x in range(int(stand.position.x) + 120, int(stand.end.x) - 20, 150):
			draw_rect(Rect2(seam_x + row * 23, riser_top - STAND_PLANK_H, 3.0, STAND_PLANK_H), WOOD_RISER)
		if row > 0:
			_draw_crowd_row(stand, riser_bottom - STAND_ROW_DEPTH, rng)

	var banner := Rect2(stand.position.x + 180.0, front_y - STAND_RISER_H + 2.0, 260.0, STAND_RISER_H - 4.0)
	var stripe_w := 18.0
	var stripe_x := banner.position.x
	var stripe_index := 0
	while stripe_x < banner.end.x:
		var color := UiPalette.ACCENT_YELLOW if stripe_index % 2 == 0 else UiPalette.INK
		draw_colored_polygon(PackedVector2Array([
			Vector2(stripe_x + 6.0, banner.position.y), Vector2(stripe_x + stripe_w + 6.0, banner.position.y),
			Vector2(stripe_x + stripe_w, banner.end.y), Vector2(stripe_x, banner.end.y),
		]), color)
		stripe_x += stripe_w
		stripe_index += 1

## Seated spectators on one row's plank: a torso slab with a head on top.
## `seat_y` is the front edge of the plank they sit on.
func _draw_crowd_row(stand: Rect2, seat_y: float, rng: RandomNumberGenerator) -> void:
	var x := stand.position.x + rng.randf_range(20.0, 70.0)
	while x < stand.end.x - 30.0:
		var shirt: Color = CROWD_SHIRTS[rng.randi() % CROWD_SHIRTS.size()]
		var skin: Color = CROWD_SKIN[rng.randi() % CROWD_SKIN.size()]
		var torso_top := seat_y - STAND_RISER_H - 18.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8.0, seat_y - STAND_RISER_H + 2.0), Vector2(x + 8.0, seat_y - STAND_RISER_H + 2.0),
			Vector2(x + 6.0, torso_top), Vector2(x - 6.0, torso_top),
		]), shirt)
		draw_rect(Rect2(x + 3.0, torso_top, 3.0, 20.0), shirt.darkened(0.2))
		draw_colored_polygon(FlatProps.octagon(Vector2(x, torso_top - 6.0), 6.0, 6.0), skin)
		x += rng.randf_range(34.0, 110.0)

## Scoreboard on two posts behind the strip near the start, showing a run time
## in yellow digits.
func _draw_scoreboard() -> void:
	var base := Vector2(start_x + 460.0, -_half_w - 44.0)
	var board := Rect2(base.x - 80.0, base.y - 130.0, 160.0, 64.0)
	draw_colored_polygon(FlatProps.octagon(base + Vector2(10.0, 2.0), 90.0, 8.0), UiPalette.SHADOW)
	for post_x: float in [board.position.x + 20.0, board.end.x - 26.0]:
		draw_rect(Rect2(post_x, board.end.y, 6.0, base.y - board.end.y), UiPalette.POST_GREY)
	draw_rect(Rect2(board.position.x, board.end.y - 6.0, board.size.x, 6.0), UiPalette.METAL_GREY)
	draw_rect(Rect2(board.position.x, board.position.y, board.size.x, board.size.y - 6.0), UiPalette.INK)
	draw_rect(Rect2(board.end.x - 10.0, board.position.y, 10.0, board.size.y - 6.0), UiPalette.VOID)
	draw_rect(Rect2(board.position.x + 4.0, board.position.y + 4.0, 5.0, board.size.y - 16.0), UiPalette.METAL_GREY)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(board.position.x + 14.0, board.position.y + 20.0), "E.T.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiPalette.TRIM_OFF_WHITE)
	draw_string(font, Vector2(board.position.x + 10.0, board.position.y + 50.0), "13.37", HORIZONTAL_ALIGNMENT_CENTER, board.size.x - 20.0, 30, UiPalette.ACCENT_YELLOW)

## The staging "christmas tree" between the lanes: a post with a light box
## carrying two columns of amber lights over a green.
func _draw_light_tree(base: Vector2) -> void:
	draw_colored_polygon(FlatProps.octagon(base + Vector2(6.0, 2.0), 18.0, 6.0), UiPalette.SHADOW)
	draw_rect(Rect2(base.x - 3.0, base.y - 70.0, 6.0, 70.0), UiPalette.POST_GREY)
	draw_rect(Rect2(base.x - 12.0, base.y - 4.0, 24.0, 6.0), UiPalette.METAL_GREY)
	var box := Rect2(base.x - 13.0, base.y - 124.0, 26.0, 56.0)
	draw_rect(box, UiPalette.INK)
	draw_rect(Rect2(box.end.x - 5.0, box.position.y, 5.0, box.size.y), UiPalette.VOID)
	for row in 4:
		for side: float in [-1.0, 1.0]:
			var color := LIGHT_GREEN if row == 3 else LIGHT_AMBER
			draw_colored_polygon(FlatProps.octagon(Vector2(base.x + side * 6.0 - 1.0, box.position.y + 9.0 + row * 12.0), 4.0, 4.0), color)

func _draw_timing_pole(base: Vector2) -> void:
	draw_rect(Rect2(base.x - 2.5, base.y - 64.0, 5.0, 64.0), UiPalette.POST_GREY)
	draw_rect(Rect2(base.x - 8.0, base.y - 76.0, 16.0, 14.0), UiPalette.INK)
	draw_colored_polygon(FlatProps.octagon(Vector2(base.x - 1.0, base.y - 69.0), 3.5, 3.5), UiPalette.DANGER_RED)

func _pit_spots() -> Array[Vector2]:
	return [
		Vector2(start_x + 180.0, _half_w + 110.0),
		Vector2(start_x + 820.0, _half_w + 104.0),
		Vector2(finish_x - 260.0, _half_w + 112.0),
	]

## Little heaps of spare tyres and oil drums along the pit side.
func _draw_pit_clutter(rng: RandomNumberGenerator) -> void:
	for spot in _pit_spots():
		FlatProps.draw_tire_stack(self, spot + Vector2(-34.0, -6.0), rng.randi_range(2, 4))
		FlatProps.draw_tire_stack(self, spot + Vector2(-6.0, 8.0), rng.randi_range(1, 3))
		FlatProps.draw_drum(self, spot + Vector2(30.0, -4.0), DRUM_COLORS[rng.randi() % DRUM_COLORS.size()])
		FlatProps.draw_drum(self, spot + Vector2(52.0, 8.0), DRUM_COLORS[rng.randi() % DRUM_COLORS.size()])

# --- Collision -----------------------------------------------------------------

## Footprints of the things a car shouldn't drive through, in local space.
func _solid_rects() -> Array[Rect2]:
	var stand := _grandstand_rect()
	var rects: Array[Rect2] = [
		Rect2(stand.position.x, stand.end.y - 40.0, stand.size.x, 40.0),
		Rect2(_half_len + 8.0, -_half_w - 20.0, 40.0, width + 30.0),
	]
	for spot in _pit_spots():
		rects.append(Rect2(spot.x - 54.0, spot.y - 20.0, 124.0, 36.0))
	return rects

func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	shape.shape = RoundedRectShape.build(rect.size, minf(12.0, rect.size.y * 0.3))
	body.add_child(shape)
	add_child(body)

# --- Geometry helpers ----------------------------------------------------------

## A rectangle whose edges wander a few pixels, so the ground isn't ruler-cut.
func _jittered_rect(rect: Rect2, step: float, amount: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var points := PackedVector2Array()
	for i in 4:
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var normal := (to - from).orthogonal().normalized()
		var steps := maxi(1, int(from.distance_to(to) / step))
		for s in steps:
			var jitter := 0.0 if s == 0 else rng.randf_range(-amount, amount)
			points.append(from.lerp(to, float(s) / steps) + normal * jitter)
	return points

func _blob(center: Vector2, blob_width: float, blob_height: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 7:
		var angle := TAU * float(i) / 7.0
		points.append(center + Vector2(cos(angle) * blob_width * 0.5 * rng.randf_range(0.8, 1.15),
				sin(angle) * blob_height * 0.5 * rng.randf_range(0.8, 1.15)))
	return points

func _rotated_quad(center: Vector2, quad_size: Vector2, angle: float) -> PackedVector2Array:
	var half := quad_size * 0.5
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		points.append(center + corner.rotated(angle))
	return points
