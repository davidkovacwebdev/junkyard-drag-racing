@tool
class_name RampEvent
extends Obstacle
## The ramp-jump event on the world map: a kicker ramp knocked together from
## salvaged boards on a timber frame (tyres shoved underneath for support), a
## smaller landing ramp across a gap of dead tyres, a hand-painted JUMP sign and
## a pennant on the lip.
##
## Extends Obstacle for the `display_name` / `interior_scene` interaction and
## the footprint collision; the scene ships no ColorRect, the art is drawn here.
## @tool so it's visible in the 2D editor.
##
## Locked until Grandpa tells the player about it ("Downhill Billie", handed
## out when "Talk Shop" is handed in): until then the prompt says so in red
## and E does nothing.

const DECK_BACK := Vector2(12.0, -34.0)
const LAUNCH_START_X := -140.0
const LAUNCH_LIP := Vector2(20.0, -20.0)
const LANDING_TOP := Vector2(62.0, 22.0)
const LANDING_END_X := 145.0

const DECK_BOARDS := [Color(0.62, 0.48, 0.32), Color(0.56, 0.42, 0.27)]
const FRAME := Color(0.4, 0.29, 0.19)
const FRAME_LIGHT := Color(0.5, 0.37, 0.24)
const UNDERSIDE := Color(0.13, 0.11, 0.09)
const PENNANT := Color(0.85, 0.45, 0.12)

## The quest that opens the ramp: it's open once that's been given.
const UNLOCK_QUEST := &"ramp_check"
## Quests that only ask for a run at it: entering the jump meets their goal.
const RUN_QUESTS: Array[StringName] = [&"ramp_check", &"ramp_again"]
const LOCKED_MESSAGE := "Ramp: Nobody's told you about this one yet"
const LOCKED_COLOR := Color(0.95, 0.2, 0.2, 1)

## Whether the player may take a run at it.
static func unlocked() -> bool:
	return Quests.has_quest(UNLOCK_QUEST) or Quests.is_complete(UNLOCK_QUEST)

## Overrides PlayerCar's default prompt while locked; empty falls back to the
## usual "Ramp: Press E to enter".
func get_interact_prompt() -> String:
	return "" if unlocked() else LOCKED_MESSAGE

func get_interact_prompt_color() -> Color:
	return Color(1, 1, 1, 1) if unlocked() else LOCKED_COLOR

## PlayerCar's place behaviour (door, then the jump scene), only once it's open.
func interact(_actor: Node = null) -> void:
	if not unlocked():
		Sfx.play(&"denied", -6.0, 0.0)
		return
	if interior_scene is PackedScene:
		Sfx.play(&"door_close", -4.0)
		SceneLoader.change_scene_packed(interior_scene)

func _draw() -> void:
	draw_set_transform(art_origin())
	var ground_y := size.y / 2.0
	_draw_shadow(ground_y)
	_draw_sign(Vector2(-118.0, ground_y + DECK_BACK.y - 6.0))
	_draw_ramp(Vector2(LAUNCH_START_X, ground_y), LAUNCH_LIP, true)
	_draw_ramp(Vector2(LANDING_END_X, ground_y), LANDING_TOP, false)
	FlatProps.draw_tire_stack(self, Vector2(46.0, ground_y - 4.0), 1, 14.0, 8.0)
	_draw_pennant(LAUNCH_LIP + DECK_BACK)

func _draw_shadow(ground_y: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(LAUNCH_START_X, ground_y + 2.0), Vector2(LAUNCH_LIP.x + 30.0, ground_y + DECK_BACK.y),
		Vector2(LANDING_END_X + 12.0, ground_y - 8.0), Vector2(LANDING_END_X + 14.0, ground_y + 6.0),
	]), UiPalette.SHADOW)

## One wedge ramp, seen from the front: the sloped deck of two-tone boards
## behind, the dark open side in front of it. `foot` is where the slope meets
## the ground, `top` the high end.
func _draw_ramp(foot: Vector2, top: Vector2, is_launch: bool) -> void:
	var back := DECK_BACK
	var board_count := DECK_BOARDS.size()
	for i in board_count:
		var near := back * (float(i) / board_count)
		var far := back * (float(i + 1) / board_count)
		draw_colored_polygon(PackedVector2Array([foot + near, top + near, top + far, foot + far]), DECK_BOARDS[i])
	if is_launch:
		var band := (foot - top).normalized() * 12.0
		draw_colored_polygon(PackedVector2Array([top, top + band, top + band + back, top + back]), UiPalette.ACCENT_YELLOW)
	var base := Vector2(top.x, foot.y)
	draw_colored_polygon(PackedVector2Array([foot, base, top]), UNDERSIDE)
	if is_launch:
		FlatProps.draw_tire_stack(self, Vector2(top.x - 26.0, foot.y), 2, 14.0, 8.0)
	draw_colored_polygon(FlatProps.sliver(foot, top, 7.0), FRAME_LIGHT)
	draw_colored_polygon(FlatProps.sliver(base + Vector2(-3.0, 0.0), top + Vector2(-3.0, 0.0), 6.0), FRAME)

func _draw_sign(base: Vector2) -> void:
	var board := Rect2(base.x - 44.0, base.y - 78.0, 88.0, 36.0)
	for post_x: float in [board.position.x + 12.0, board.end.x - 18.0]:
		draw_rect(Rect2(post_x, board.end.y, 5.0, base.y - board.end.y), UiPalette.POST_GREY)
	var pivot := board.get_center()
	draw_set_transform(art_origin() + pivot, deg_to_rad(-3.0), Vector2.ONE)
	var local := Rect2(board.position - pivot, board.size)
	draw_rect(local, UiPalette.CARDBOARD_BASE)
	draw_rect(Rect2(local.end.x - 7.0, local.position.y, 7.0, local.size.y), UiPalette.CARDBOARD_SHADE)
	draw_string(ThemeDB.fallback_font, local.position + Vector2(0.0, 25.0), "JUMP!", HORIZONTAL_ALIGNMENT_CENTER, local.size.x - 6.0, 22, UiPalette.DANGER_RED)
	draw_set_transform(art_origin())

func _draw_pennant(lip_back: Vector2) -> void:
	var pole_top := lip_back + Vector2(-4.0, -56.0)
	draw_rect(Rect2(pole_top.x, pole_top.y, 4.0, lip_back.y - pole_top.y), UiPalette.POST_GREY)
	draw_colored_polygon(PackedVector2Array([
		pole_top + Vector2(4.0, 2.0), pole_top + Vector2(34.0, 10.0), pole_top + Vector2(4.0, 20.0),
	]), PENNANT)
