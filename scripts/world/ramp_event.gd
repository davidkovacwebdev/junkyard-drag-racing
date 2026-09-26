@tool
class_name RampEvent
extends Obstacle
## The ramp-jump event on the world map: a kicker ramp knocked together from
## salvaged boards on an open timber frame (tyres and a drum shoved underneath
## for support), a smaller landing ramp across a gap of dead tyres, a hand-
## painted JUMP sign and a pennant on the lip.
##
## Extends Obstacle for the `display_name` / `interior_scene` interaction and
## the footprint collision; the scene ships no ColorRect, the art is drawn here.
## @tool so it's visible in the 2D editor.

const DECK_BACK := Vector2(12.0, -34.0)
const LAUNCH_START_X := -140.0
const LAUNCH_LIP := Vector2(20.0, -20.0)
const LANDING_TOP := Vector2(62.0, 22.0)
const LANDING_END_X := 145.0

const DECK_BOARDS := [
	Color(0.62, 0.48, 0.32), Color(0.56, 0.42, 0.27),
	Color(0.68, 0.57, 0.41), Color(0.58, 0.45, 0.3),
]
const FRAME := Color(0.4, 0.29, 0.19)
const FRAME_LIGHT := Color(0.5, 0.37, 0.24)
const UNDERSIDE := Color(0.13, 0.11, 0.09)
const SHEET_METAL := Color(0.52, 0.56, 0.63)
const DRUM := Color(0.55, 0.3, 0.18)
const PENNANT := Color(0.85, 0.45, 0.12)

func _draw() -> void:
	var ground_y := size.y / 2.0
	_draw_shadow(ground_y)
	_draw_sign(Vector2(-118.0, ground_y + DECK_BACK.y - 6.0))
	_draw_ramp(Vector2(LAUNCH_START_X, ground_y), LAUNCH_LIP, true)
	_draw_ramp(Vector2(LANDING_END_X, ground_y), LANDING_TOP, false)
	FlatProps.draw_tire_stack(self, Vector2(40.0, ground_y - 2.0), 1, 14.0, 8.0)
	FlatProps.draw_tire_stack(self, Vector2(54.0, ground_y - 16.0), 1, 14.0, 8.0)
	_draw_pennant(LAUNCH_LIP + DECK_BACK)

func _draw_shadow(ground_y: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(LAUNCH_START_X, ground_y + 2.0), Vector2(LAUNCH_LIP.x + 30.0, ground_y + DECK_BACK.y),
		Vector2(LANDING_END_X + 12.0, ground_y - 8.0), Vector2(LANDING_END_X + 14.0, ground_y + 6.0),
	]), UiPalette.SHADOW)

## One wedge ramp, seen from the front: the sloped deck of mismatched boards
## behind, the open side frame in front of it. `foot` is where the slope meets
## the ground, `top` the high end.
func _draw_ramp(foot: Vector2, top: Vector2, is_launch: bool) -> void:
	var back := DECK_BACK
	var board_count := DECK_BOARDS.size()
	for i in board_count:
		var near := back * (float(i) / board_count)
		var far := back * (float(i + 1) / board_count)
		draw_colored_polygon(PackedVector2Array([foot + near, top + near, top + far, foot + far]), DECK_BOARDS[i])
	var along := (top - foot)
	for seam in [0.3, 0.62]:
		var seam_point: Vector2 = foot + along * seam
		draw_colored_polygon(FlatProps.sliver(seam_point, seam_point + back, 3.0), FRAME)
	if is_launch:
		_draw_sheet_patch(foot + along * 0.42, along.normalized(), back)
		_draw_hazard_lip(top, -along.normalized(), back)

	var base := Vector2(top.x, foot.y)
	var side := PackedVector2Array([foot, base, top])
	draw_colored_polygon(side, UNDERSIDE)
	if is_launch:
		FlatProps.draw_tire_stack(self, Vector2(top.x - 22.0, foot.y), 3, 14.0, 8.0)
		FlatProps.draw_drum(self, Vector2(top.x - 54.0, foot.y), DRUM, 11.0, 28.0)
	_draw_side_frame(foot, base, top)

## Beams along the ground, up the slope and down the high end, plus a couple of
## uprights and a cross brace.
func _draw_side_frame(foot: Vector2, base: Vector2, top: Vector2) -> void:
	draw_colored_polygon(FlatProps.sliver(foot, base, 6.0), FRAME)
	draw_colored_polygon(FlatProps.sliver(foot, top, 7.0), FRAME_LIGHT)
	draw_colored_polygon(FlatProps.sliver(base + Vector2(-3.0, 0.0), top + Vector2(-3.0, 0.0), 6.0), FRAME)
	for t: float in [0.45, 0.75]:
		var on_slope := foot.lerp(top, t)
		draw_colored_polygon(FlatProps.sliver(on_slope, Vector2(on_slope.x, foot.y), 5.0), FRAME)
	draw_colored_polygon(FlatProps.sliver(foot.lerp(top, 0.45) + Vector2(0.0, 4.0), base + Vector2(-4.0, -4.0), 4.0), FRAME_LIGHT)

func _draw_sheet_patch(center: Vector2, along: Vector2, back: Vector2) -> void:
	var half_along := along * 18.0
	var depth := back * 0.6
	var start := center + back * 0.2
	var patch := PackedVector2Array([start - half_along, start + half_along, start + half_along + depth, start - half_along + depth])
	draw_colored_polygon(patch, SHEET_METAL)
	draw_colored_polygon(PackedVector2Array([patch[1] - along * 5.0, patch[1], patch[2], patch[2] - along * 5.0]), SHEET_METAL.darkened(0.2))
	for corner in [patch[0] + along * 4.0 + back * 0.1, patch[3] + along * 4.0 - back * 0.1]:
		draw_colored_polygon(FlatProps.octagon(corner, 1.6, 1.6), UiPalette.INK)

## Yellow and ink stripes painted across the end of the launch deck.
func _draw_hazard_lip(top: Vector2, down_slope: Vector2, back: Vector2) -> void:
	var band := down_slope * 14.0
	var stripes := 5
	for i in stripes:
		var near := back * (float(i) / stripes)
		var far := back * (float(i + 1) / stripes)
		var color := UiPalette.ACCENT_YELLOW if i % 2 == 0 else UiPalette.INK
		draw_colored_polygon(PackedVector2Array([top + near, top + near + band, top + far + band + Vector2(-3.0, 0.0), top + far]), color)

func _draw_sign(base: Vector2) -> void:
	var board := Rect2(base.x - 44.0, base.y - 78.0, 88.0, 36.0)
	for post_x: float in [board.position.x + 12.0, board.end.x - 18.0]:
		draw_rect(Rect2(post_x, board.end.y, 5.0, base.y - board.end.y), UiPalette.POST_GREY)
	var tilt := deg_to_rad(-3.0)
	var pivot := board.get_center()
	draw_set_transform(pivot, tilt, Vector2.ONE)
	var local := Rect2(board.position - pivot, board.size)
	draw_rect(Rect2(local.position + Vector2(4.0, 5.0), local.size), UiPalette.SHADOW)
	draw_rect(local, UiPalette.CARDBOARD_BASE)
	draw_rect(Rect2(local.end.x - 7.0, local.position.y, 7.0, local.size.y), UiPalette.CARDBOARD_SHADE)
	draw_rect(Rect2(local.position.x, local.end.y - 5.0, local.size.x, 5.0), UiPalette.CARDBOARD_DARK)
	draw_string(ThemeDB.fallback_font, local.position + Vector2(0.0, 25.0), "JUMP!", HORIZONTAL_ALIGNMENT_CENTER, local.size.x - 6.0, 22, UiPalette.DANGER_RED)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_pennant(lip_back: Vector2) -> void:
	var pole_top := lip_back + Vector2(-4.0, -56.0)
	draw_rect(Rect2(pole_top.x, pole_top.y, 4.0, lip_back.y - pole_top.y), UiPalette.POST_GREY)
	draw_colored_polygon(PackedVector2Array([
		pole_top + Vector2(4.0, 2.0), pole_top + Vector2(34.0, 10.0), pole_top + Vector2(4.0, 20.0),
	]), PENNANT)
	draw_colored_polygon(PackedVector2Array([
		pole_top + Vector2(4.0, 13.0), pole_top + Vector2(28.0, 11.5), pole_top + Vector2(4.0, 20.0),
	]), PENNANT.darkened(0.2))
