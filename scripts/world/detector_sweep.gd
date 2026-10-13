class_name DetectorSweep
extends Node2D
## Grandpa's metal detector, switched on from the trunk (TreasureStory turns
## it on and off). It rides along with the player's car and beeps:
##
## - now and then at random, wherever the car is (it's an old detector);
## - within `LISTEN_RANGE` of `target` (the real treasure, during "Beep
##   Beep"), steadily, faster and higher the closer the car gets.
##
## E marks the spot under the car: close enough to `target` and `marked`
## fires with it; too far and it's "nothing solid here". A small board in the
## bottom-left says it's on and what E does. Freed when switched off.

signal marked(spot: Vector2)

## Where the steady beeping starts, and how near the car has to be for E to
## count as the spot.
const LISTEN_RANGE := 700.0
const MARK_RANGE := 70.0
## Seconds between beeps: far out at the edge of LISTEN_RANGE, and right on
## top of it.
const SLOW_BEEP := 1.4
const FAST_BEEP := 0.07
## Pitch of the beep, far and near.
const LOW_PITCH := 0.85
const HIGH_PITCH := 1.5
## How long between the random beeps out of range.
const STRAY_BEEP := Vector2(2.5, 7.0)
## The little lamp over the car that flashes with each beep.
const LAMP_LIFT := 70.0
const LAMP_SIZE := 9.0
const LAMP_COLOR := Color(0.95, 0.75, 0.1, 1)
const FLASH_TIME := 0.08
const HUD_LAYER := 40
const HUD_TEXT := "METAL DETECTOR ON\nE  mark the spot     use it again (I) to switch off"

## The treasure; only listened for when `has_target`.
var target := Vector2.ZERO
var has_target := false

var _car: Node2D
var _until_beep := 1.0
var _flash := 0.0
var _hud: CanvasLayer

func _ready() -> void:
	top_level = true
	z_index = 20
	_build_hud()

func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()

func _process(delta: float) -> void:
	_car = get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if _car == null:
		return
	global_position = _car.global_position
	_hud.visible = not Cutscenes.is_active() and Journal.hud_allowed()
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()
	if Cutscenes.is_active():
		return
	_until_beep -= delta
	if _until_beep > 0.0:
		return
	var closeness := _closeness()
	if closeness > 0.0:
		_beep(closeness)
		_until_beep = lerpf(SLOW_BEEP, FAST_BEEP, closeness)
	else:
		_beep(0.0)
		_until_beep = randf_range(STRAY_BEEP.x, STRAY_BEEP.y)

## 0 outside LISTEN_RANGE (or with no target), up to 1 right on top of it.
func _closeness() -> float:
	if not has_target or _car == null:
		return 0.0
	var distance := _car.global_position.distance_to(target)
	if distance >= LISTEN_RANGE:
		return 0.0
	# Eased, so the last stretch is where it really races.
	return pow(1.0 - distance / LISTEN_RANGE, 1.6)

func _beep(closeness: float) -> void:
	var player := Sfx.play(&"detector_tick", -8.0, 0.0)
	if player != null:
		player.pitch_scale = lerpf(LOW_PITCH, HIGH_PITCH, closeness)
	_flash = FLASH_TIME

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_E:
		return
	if _car == null or Cutscenes.is_active() or get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	if has_target and _car.global_position.distance_to(target) <= MARK_RANGE:
		marked.emit(target)
		return
	Sfx.play(&"denied", -6.0, 0.0)
	Pickup.spawn_float_text(get_parent(), _car.global_position + Vector2(0.0, -LAMP_LIFT - 30.0),
			"Nothing solid here. Keep listening.")

func _draw() -> void:
	if _flash <= 0.0:
		return
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -LAMP_LIFT), LAMP_SIZE, LAMP_SIZE), LAMP_COLOR)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = HUD_LAYER
	add_child(_hud)
	var board := ScrapPanel.new()
	board.body_color = UiPalette.CARDBOARD_BASE
	board.shade_color = UiPalette.CARDBOARD_SHADE
	board.skirt_color = UiPalette.CARDBOARD_DARK
	board.tilt_degrees = 1.0
	board.jitter_seed = 211
	board.nails = false
	board.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	board.offset_left = 20.0
	board.offset_right = 470.0
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
