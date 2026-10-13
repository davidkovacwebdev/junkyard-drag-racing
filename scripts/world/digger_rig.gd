class_name DiggerRig
extends Node2D
## The junkyard's little digger: tracks, a yellow cab and one arm with a
## bucket on the end, drawn facing right (mirror it with scale.x).
##
## Two jobs:
## - a prop, standing about (DiggerRevealCutscene shows it off with `dig()`);
## - the player's ride during "Dig It", or while it's borrowed from the
##   junkyard counter after ($100, ScrapDealer): PlayerCar hides its own car and
##   drives this instead (slower, no sprint; see PlayerCar), with `driven`
##   on. Then F scoops the ground in front of the bucket: each scoop digs the
##   DigHole there one stage deeper (three make a hole), and tells the
##   TreasureStory group (`on_hole_dug`), which knows where the chest is. A
##   small board in the bottom-left says what F does.

const BODY := Color(0.85, 0.65, 0.2, 1)
const BODY_SHADE := Color(0.7, 0.52, 0.15, 1)
const ARM := Color(0.78, 0.58, 0.17, 1)
const TRACKS := Color(0.2, 0.2, 0.22, 1)
const GLASS := Color(0.4, 0.5, 0.52, 1)
const BUCKET := Color(0.3, 0.3, 0.32, 1)
const DIRT := Color(0.42, 0.32, 0.22, 1)
## The arm: where the boom hinges on the cab, and where the elbow and the
## bucket end up at rest and dug in.
const PIVOT := Vector2(16.0, -22.0)
const ELBOW_REST := Vector2(58.0, -58.0)
const ELBOW_DUG := Vector2(72.0, -30.0)
const WRIST_REST := Vector2(84.0, -6.0)
const WRIST_DUG := Vector2(96.0, 26.0)
## Where a scoop bites the ground, from the digger's middle (facing right).
const BITE := Vector2(96.0, 22.0)
const DOWN_TIME := 0.4
const HOLD_TIME := 0.2
const UP_TIME := 0.45
const HUD_LAYER := 40
const HUD_TEXT := "DIGGER\nF  dig     (no sprint in this thing)"

## WorldState claim while the player has it on loan (ScrapDealer).
const RENTED := "digger_rented"
const DIG_QUEST := &"treasure_dig"

## The player's ride: F digs, and the board shows.
var driven := false
## 0 at rest, 1 with the bucket in the ground.
var dig_t := 0.0:
	set(value):
		dig_t = value
		queue_redraw()
var _digging := false
var _full := false
var _hud: CanvasLayer

func _ready() -> void:
	if driven:
		_build_hud()

func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()

## Whether the player's driving the digger rather than their car: during
## "Dig It", or on loan.
static func in_use() -> bool:
	return Quests.has_quest(DIG_QUEST) or WorldState.is_claimed(RENTED)

func is_digging() -> bool:
	return _digging

## One scoop: the arm comes down, bites, and lifts a bucket of dirt.
func dig() -> void:
	if _digging:
		return
	_digging = true
	_full = false
	Sfx.play_at(&"digger_scoop", global_position, -4.0)
	var tween := create_tween()
	tween.tween_property(self, "dig_t", 1.0, DOWN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(HOLD_TIME)
	tween.tween_callback(func() -> void: _full = true)
	tween.tween_property(self, "dig_t", 0.0, UP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_full = false
	queue_redraw()
	_digging = false

## Where the bucket bites, in global space.
func bite_point() -> Vector2:
	return to_global(BITE)

func _process(_delta: float) -> void:
	if not driven:
		return
	_hud.visible = not Cutscenes.is_active() and Journal.hud_allowed()

func _unhandled_input(event: InputEvent) -> void:
	if not driven:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F:
		return
	if _digging or Cutscenes.is_active() or get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	_scoop()

func _scoop() -> void:
	var point := bite_point()
	await dig()
	var sortables := get_tree().current_scene.get_node_or_null(^"Sortables") if get_tree().current_scene != null else null
	if sortables == null:
		return
	var hole := DigHole.scoop(sortables, point)
	get_tree().call_group(TreasureStory.GROUP, &"on_hole_dug", hole)

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-58.0, 12.0), Vector2(34.0, 12.0), Vector2(42.0, 20.0),
			Vector2(34.0, 30.0), Vector2(-58.0, 30.0), Vector2(-66.0, 20.0)]), TRACKS)
	draw_colored_polygon(PackedVector2Array([Vector2(-52.0, -34.0), Vector2(20.0, -30.0),
			Vector2(22.0, 12.0), Vector2(-54.0, 12.0)]), BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(-54.0, 3.0), Vector2(22.0, 3.0),
			Vector2(22.0, 12.0), Vector2(-54.0, 12.0)]), BODY_SHADE)
	draw_colored_polygon(PackedVector2Array([Vector2(-44.0, -28.0), Vector2(-12.0, -26.0),
			Vector2(-12.0, -6.0), Vector2(-44.0, -6.0)]), GLASS)
	var elbow := ELBOW_REST.lerp(ELBOW_DUG, dig_t)
	var wrist := WRIST_REST.lerp(WRIST_DUG, dig_t)
	draw_colored_polygon(FlatProps.sliver(PIVOT, elbow, 12.0), ARM)
	draw_colored_polygon(FlatProps.sliver(elbow, wrist, 9.0), ARM)
	draw_colored_polygon(PackedVector2Array([wrist + Vector2(-12.0, -6.0), wrist + Vector2(12.0, -4.0),
			wrist + Vector2(8.0, 14.0), wrist + Vector2(-10.0, 10.0)]), BUCKET)
	if _full:
		draw_colored_polygon(FlatProps.octagon(wrist + Vector2(0.0, -8.0), 13.0, 7.0), DIRT)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = HUD_LAYER
	add_child(_hud)
	var board := ScrapPanel.new()
	board.body_color = UiPalette.CARDBOARD_BASE
	board.shade_color = UiPalette.CARDBOARD_SHADE
	board.skirt_color = UiPalette.CARDBOARD_DARK
	board.tilt_degrees = -1.0
	board.jitter_seed = 223
	board.nails = false
	board.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	board.offset_left = 20.0
	board.offset_right = 380.0
	board.offset_top = -96.0
	board.offset_bottom = -20.0
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(board)
	var label := Label.new()
	label.text = HUD_TEXT
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", UiPalette.TEXT_BROWN)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 16.0
	label.offset_top = 10.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(label)
