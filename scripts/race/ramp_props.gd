@tool
class_name RampProps
extends Node2D
## Scenery along the ramp jump track: a START banner, a warning sign on the drop,
## the JUMP! sign on the kicker lip, a pennant across the pit, a small crowd on the landing,
## tyre stacks and drums by the end wall, plus a few bits of junk
## buried in the dirt. Nothing here collides. It sits behind the road (the road
## band hides the prop feet) and in front of the dirt.
##
## Positions are in track coordinates and match track_ramp_single.tscn.

const HILL_START_X := 500.0
const HILL_RUN := 2800.0
const HILL_DROP := 2700.0
const LIP := Vector2(3829.92, 2548.05)
const LANDING_START_X := 5329.92
const RECEIVER_RUN := 800.0
const RECEIVER_DROP := 200.0
const LANDING_FLAT_Y := LIP.y + RECEIVER_DROP
## Props stand this far below the road top so the road band hides their feet.
const FOOT_SINK := 24.0

const RUST := Color(0.55, 0.28, 0.14)
const DRUM_BLUE := Color(0.33, 0.40, 0.48)
const PENNANT := Color(0.85, 0.45, 0.12)
const SIGN_YELLOW := Color(0.88, 0.70, 0.18)
const BURIED_TYRE := Color(0.2, 0.155, 0.12)
const BURIED_HOLE := Color(0.15, 0.11, 0.09)
const BURIED_PANEL := Color(0.33, 0.26, 0.2)
const SHIRT_COLORS := [Color(0.45, 0.52, 0.40), Color(0.62, 0.35, 0.25), Color(0.40, 0.45, 0.58), Color(0.70, 0.60, 0.30)]
const SKIN_COLORS := [Color(0.85, 0.68, 0.52), Color(0.62, 0.45, 0.32)]

func _draw() -> void:
	_draw_buried_junk()

	_draw_board_sign(Vector2(-230.0, FOOT_SINK), Vector2(620.0, 110.0), 430.0, "START", -2.0)
	FlatProps.draw_tire_stack(self, Vector2(-900.0, FOOT_SINK), 3, 50.0, 28.0)
	FlatProps.draw_drum(self, Vector2(-720.0, FOOT_SINK), RUST, 36.0, 90.0)

	_draw_warning_sign(Vector2(1500.0, _hill_y(1500.0) + FOOT_SINK))
	# The kicker deck curves down away from the lip, so the posts run deep and
	# the kicker frame hides whatever is below the deck.
	_draw_board_sign(Vector2(LIP.x - 140.0, LIP.y + 200.0), Vector2(250.0, 100.0), 470.0, "JUMP!", 3.0)
	_draw_pennant(Vector2(LANDING_START_X + 90.0, _landing_y(LANDING_START_X + 90.0) + FOOT_SINK))
	FlatProps.draw_tire_stack(self, Vector2(5560.0, _landing_y(5560.0) + FOOT_SINK), 2, 46.0, 26.0)

	for i in 4:
		_draw_spectator(Vector2(6400.0 + 300.0 * i + (i % 2) * 40.0, LANDING_FLAT_Y + FOOT_SINK), i)

	FlatProps.draw_drum(self, Vector2(7880.0, LANDING_FLAT_Y + FOOT_SINK), DRUM_BLUE, 36.0, 90.0)
	FlatProps.draw_drum(self, Vector2(7980.0, LANDING_FLAT_Y + FOOT_SINK), RUST, 36.0, 90.0)
	FlatProps.draw_tire_stack(self, Vector2(8240.0, LANDING_FLAT_Y + FOOT_SINK), 4, 50.0, 28.0)

func _hill_y(x: float) -> float:
	var t := clampf((x - HILL_START_X) / HILL_RUN, 0.0, 1.0)
	return HILL_DROP * (1.0 - cos(PI * t)) * 0.5

func _landing_y(x: float) -> float:
	var t := clampf((x - LANDING_START_X) / RECEIVER_RUN, 0.0, 1.0)
	return LIP.y + RECEIVER_DROP * sin(PI * t * 0.5)

## Cardboard board on two posts with painted text, tilted a few degrees.
func _draw_board_sign(base: Vector2, board_size: Vector2, height: float, text: String, tilt_degrees: float) -> void:
	var board := Rect2(base.x - board_size.x * 0.5, base.y - height, board_size.x, board_size.y)
	for post_x: float in [board.position.x + board_size.x * 0.15, board.end.x - board_size.x * 0.15 - 16.0]:
		draw_rect(Rect2(post_x, board.end.y, 16.0, base.y - board.end.y), UiPalette.POST_GREY)
	var pivot := board.get_center()
	draw_set_transform(pivot, deg_to_rad(tilt_degrees), Vector2.ONE)
	var local := Rect2(board.position - pivot, board.size)
	draw_rect(local, UiPalette.CARDBOARD_BASE)
	draw_rect(Rect2(local.end.x - 18.0, local.position.y, 18.0, local.size.y), UiPalette.CARDBOARD_SHADE)
	var font_size := int(board_size.y * 0.62)
	draw_string(ThemeDB.fallback_font, local.position + Vector2(0.0, board_size.y * 0.5 + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, local.size.x - 18.0, font_size, UiPalette.DANGER_RED)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Yellow triangle with a chunky "!" on a post.
func _draw_warning_sign(base: Vector2) -> void:
	var center := base + Vector2(0.0, -300.0)
	draw_rect(Rect2(base.x - 8.0, center.y, 16.0, base.y - center.y), UiPalette.POST_GREY)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -90.0), center + Vector2(88.0, 62.0), center + Vector2(-84.0, 60.0)]), SIGN_YELLOW)
	draw_rect(Rect2(center.x - 9.0, center.y - 40.0, 18.0, 58.0), UiPalette.INK)
	draw_rect(Rect2(center.x - 9.0, center.y + 28.0, 18.0, 18.0), UiPalette.INK)

func _draw_pennant(base: Vector2) -> void:
	var pole_top := base + Vector2(0.0, -300.0)
	draw_rect(Rect2(pole_top.x - 7.0, pole_top.y, 14.0, base.y - pole_top.y), UiPalette.POST_GREY)
	draw_colored_polygon(PackedVector2Array([
		pole_top + Vector2(7.0, 4.0), pole_top + Vector2(120.0, 30.0), pole_top + Vector2(7.0, 64.0),
	]), PENNANT)

## A chunky spectator: a shirt block and a head. Every other one has an arm up.
func _draw_spectator(feet: Vector2, index: int) -> void:
	var shirt: Color = SHIRT_COLORS[index % SHIRT_COLORS.size()]
	var skin: Color = SKIN_COLORS[index % SKIN_COLORS.size()]
	var lean := 6.0 if index % 2 == 0 else -5.0
	draw_colored_polygon(PackedVector2Array([
		feet + Vector2(-38.0, 0.0), feet + Vector2(38.0, 0.0), feet + Vector2(30.0 + lean, -150.0), feet + Vector2(-30.0 + lean, -150.0),
	]), shirt)
	if index % 2 == 1:
		draw_colored_polygon(FlatProps.sliver(feet + Vector2(24.0 + lean, -135.0), feet + Vector2(52.0 + lean, -230.0), 20.0), shirt)
	draw_colored_polygon(FlatProps.octagon(feet + Vector2(lean, -180.0), 32.0, 34.0), skin)

## A handful of tyres and panels half-sunk in the dirt below the road.
func _draw_buried_junk() -> void:
	_draw_buried_tyre(Vector2(-1500.0, 300.0), 70.0)
	_draw_buried_panel(Vector2(-600.0, 420.0), Vector2(110.0, 34.0), 0.3)
	_draw_buried_tyre(Vector2(900.0, _hill_y(900.0) + 260.0), 64.0)
	_draw_buried_panel(Vector2(1800.0, _hill_y(1800.0) + 330.0), Vector2(130.0, 36.0), -0.4)
	_draw_buried_tyre(Vector2(2600.0, _hill_y(2600.0) + 280.0), 58.0)
	_draw_buried_tyre(Vector2(6100.0, LANDING_FLAT_Y + 320.0), 66.0)
	_draw_buried_panel(Vector2(7100.0, LANDING_FLAT_Y + 400.0), Vector2(120.0, 34.0), 0.2)
	_draw_buried_tyre(Vector2(9300.0, LANDING_FLAT_Y + 290.0), 70.0)

func _draw_buried_tyre(center: Vector2, radius: float) -> void:
	draw_colored_polygon(FlatProps.octagon(center, radius, radius), BURIED_TYRE)
	draw_colored_polygon(FlatProps.octagon(center, radius * 0.45, radius * 0.45), BURIED_HOLE)

func _draw_buried_panel(center: Vector2, half_size: Vector2, angle: float) -> void:
	var points := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(center + (corner * half_size).rotated(angle))
	draw_colored_polygon(points, BURIED_PANEL)
