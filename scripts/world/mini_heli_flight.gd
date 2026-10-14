class_name MiniHeliFlight
extends Node
## The player up in Grandpa's homemade helicopter ("Test Pilot"). Takes the
## car over (PlayerCar.set_flight()): the car turns into the helicopter high
## over everything, the camera pulls way back like traveler mode (F6), and the
## arrow keys fly it with some lag, the way the car steers. The player whoops
## along (CarChatter). After FLIGHT_SECONDS it starts breaking down: black
## smoke, coughing, wobbling and slowing to a stop, and then `on_crash` is
## called (HeliTestStory plays the crash). `finish()` gives the car back.
## Made by HeliTestStory when the player climbs in.

const SPEED := 1500.0
## How fast it gets up to speed and turns (the lag), and drifts to a stop.
const ACCELERATION := 900.0
const DRIFT := 450.0
const ALTITUDE := 260.0
const BOB_PIXELS := 8.0
const TAKEOFF_SECONDS := 2.2
const FLIGHT_SECONDS := 30.0
const BREAKDOWN_SECONDS := 5.0
## How far back the camera pulls while flying (WorldCamera zoom).
const ZOOM := 0.3
## Nose down this far at full speed.
const PITCH := 0.18
const WOBBLE := 0.14
const ROTOR_VOLUME_DB := -8.0
const SPUTTER_EVERY := Vector2(0.5, 0.9)
const LINE_EVERY := 4.5
const FUN_LINES: Array[String] = ["Wow, this is so fun!", "Woooow!", "Woo hooooo!", "Let's gooo!", "Go gramps go!"]
const BREAKDOWN_LINES: Array[String] = ["Uh... gramps?", "Why is it smoking?!", "No no no no no!"]

## Called once it's come to a stop, broken: time for the crash.
var on_crash: Callable

var _car: PlayerCar
var _heli: MiniHeli
var _shadow: Polygon2D
var _rotor: SustainedSound
var _chatter: CarChatter
var _camera: WorldCamera
var _time := 0.0
var _velocity := Vector2.ZERO
var _facing_right := true
var _line_timer := 2.5
var _next_line := 0
var _sputter := 0.0
var _breaking := false
var _crashed := false

## Puts the player in the air from `at`, where the helicopter was parked.
func begin(car: PlayerCar, at: Vector2) -> void:
	_car = car
	car.park(at, true)
	car.set_flight(self)
	_shadow = Polygon2D.new()
	_shadow.polygon = FlatProps.octagon(Vector2.ZERO, 120.0, 20.0)
	_shadow.color = UiPalette.SHADOW
	car.add_child(_shadow)
	_heli = MiniHeli.new()
	_heli.z_index = 100
	car.add_child(_heli)
	_heli.smoke_parent = car.get_parent()
	_heli.seat_pilot(PlayerProfile.character)
	_rotor = SustainedSound.new()
	_rotor.sound_name = &"mini_heli_rotor_loop"
	_rotor.base_volume_db = ROTOR_VOLUME_DB
	_rotor.fade_in_time = 0.6
	_rotor.fade_out_time = 0.6
	car.add_child(_rotor)
	_chatter = CarChatter.new()
	add_child(_chatter)
	_camera = car.get_node_or_null(^"Camera2D") as WorldCamera
	if _camera != null:
		_camera.set_zoom_override(ZOOM)
	Sfx.play(&"ignition_click", -6.0, 0.0)

## Every physics frame while it has the car (PlayerCar calls it).
func fly(delta: float) -> void:
	if _car == null:
		return
	_time += delta
	var takeoff := clampf(_time / TAKEOFF_SECONDS, 0.0, 1.0)
	var broken := clampf((_time - FLIGHT_SECONDS) / BREAKDOWN_SECONDS, 0.0, 1.0)
	_heli.spin = takeoff * (1.0 - 0.6 * broken)
	_rotor.set_level(takeoff)
	_rotor.pitch_scale = 0.6 + 0.45 * _heli.spin
	var altitude := ALTITUDE * ease(takeoff, -2.0) - 60.0 * broken + sin(_time * 2.0) * BOB_PIXELS * takeoff
	_heli.position = Vector2(0.0, -altitude)
	_shadow.scale = Vector2.ONE * lerpf(1.0, 0.55, altitude / ALTITUDE)

	var input := Vector2.ZERO
	if takeoff >= 1.0 and not _crashed:
		input = _car.drive_input()
	var top_speed := SPEED * (1.0 - broken)
	var target := input.normalized() * top_speed
	_velocity = _velocity.move_toward(target, (ACCELERATION if input != Vector2.ZERO else DRIFT) * delta)
	_velocity = _velocity.limit_length(maxf(top_speed, 40.0))
	_car.velocity = _velocity
	_car.global_position += _velocity * delta
	if input.x != 0.0:
		_facing_right = input.x > 0.0
	_heli.scale.x = 1.0 if _facing_right else -1.0
	_heli.rotation = PITCH * _velocity.x / SPEED + sin(_time * 9.0) * WOBBLE * broken

	if broken > 0.0:
		_break_down(delta)
	elif takeoff >= 1.0:
		_whoop(delta)
	if broken >= 1.0 and not _crashed:
		_crashed = true
		_chatter.clear()
		if on_crash.is_valid():
			on_crash.call()

func _whoop(delta: float) -> void:
	_line_timer -= delta
	if _line_timer > 0.0 or _chatter.is_talking():
		return
	_line_timer = LINE_EVERY
	_player_says(FUN_LINES[_next_line % FUN_LINES.size()])
	_next_line += 1

func _break_down(delta: float) -> void:
	if not _breaking:
		_breaking = true
		_heli.smoking = true
		_chatter.clear()
		for line in BREAKDOWN_LINES:
			_player_says(line)
	_sputter -= delta
	if _sputter <= 0.0:
		_sputter = randf_range(SPUTTER_EVERY.x, SPUTTER_EVERY.y)
		Sfx.play(&"heli_sputter", -6.0, 0.08)

func _player_says(line: String) -> void:
	_chatter.say(PlayerProfile.display_name(), PlayerProfile.character, line)
	Quests.log_line(HeliTestStory.QUEST, PlayerProfile.display_name(), line)

## Gives the car back, on the ground, and clears the helicopter away.
func finish() -> void:
	if _car != null and is_instance_valid(_car):
		_car.set_flight(null)
		if _camera != null:
			_camera.set_zoom_override(0.0)
	for node: Node in [_heli, _shadow, _rotor]:
		if is_instance_valid(node):
			node.queue_free()
	_car = null
	queue_free()
