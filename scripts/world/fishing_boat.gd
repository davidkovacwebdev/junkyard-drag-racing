class_name FishingBoat
extends Node2D
## A little fishing boat puttering around the sea within `roam_radius` of
## where it starts. It wanders, turns away before it would run aground, heads
## back once it strays too far, and now and then cuts the motor and sits still
## a while to fish. The hull is a CoastProp boat (the same one moored at the
## port); this node draws the wake behind it and carries the motor's
## `boat_putter_loop`.

@export var terrain_path: NodePath = ^"../../Terrain"
@export var roam_radius: float = 2200.0
@export var speed: float = 90.0

const WAKE := Color(0.9, 0.97, 1.0, 0.45)
const LOOK_AHEAD := 420.0
const AVOID_ANGLE := 0.6
const TURN_RATE := 0.5
const WANDER_RATE := 0.15
const STEER_CHECK_INTERVAL := 0.3
const FISHING_TIME := Vector2(6.0, 14.0)
const SAILING_TIME := Vector2(18.0, 40.0)
const ACCELERATION := 30.0
const MOTOR_DB := -4.0
const MOTOR_HEARING_DISTANCE := 1800.0

var _terrain: TerrainNetwork
var _home := Vector2.ZERO
var _hull: CoastProp
var _motor: SustainedSound
var _heading := 0.0
var _wanted_heading := 0.0
var _current_speed := 0.0
var _steer_check := 0.0
var _mode_timer := 0.0
var _fishing := false
var _time := 0.0

func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as TerrainNetwork
	if _terrain != null:
		_terrain.ensure_built()
	_home = global_position
	_heading = randf() * TAU
	_wanted_heading = _heading
	_mode_timer = randf_range(SAILING_TIME.x, SAILING_TIME.y)
	_hull = CoastProp.new()
	_hull.kind = CoastProp.Kind.BOAT
	_hull.bob_phase = randf() * TAU
	add_child(_hull)
	_motor = SustainedSound.new()
	_motor.sound_name = &"boat_putter_loop"
	_motor.base_volume_db = MOTOR_DB
	_motor.fade_in_time = 1.0
	_motor.fade_out_time = 1.0
	_motor.max_distance = MOTOR_HEARING_DISTANCE
	add_child(_motor)

func _process(delta: float) -> void:
	_time += delta
	_mode_timer -= delta
	if _mode_timer <= 0.0:
		_fishing = not _fishing
		var range_for_mode := FISHING_TIME if _fishing else SAILING_TIME
		_mode_timer = randf_range(range_for_mode.x, range_for_mode.y)
	_steer_check -= delta
	if _steer_check <= 0.0 and _terrain != null:
		_steer_check = STEER_CHECK_INTERVAL
		_choose_heading()
	_wanted_heading += sin(_time * WANDER_RATE) * WANDER_RATE * delta
	_heading = rotate_toward(_heading, _wanted_heading, TURN_RATE * delta)
	var target_speed := 0.0 if _fishing else speed
	_current_speed = move_toward(_current_speed, target_speed, ACCELERATION * delta)
	global_position += Vector2.from_angle(_heading) * _current_speed * delta
	var direction_x := cos(_heading)
	if absf(direction_x) > 0.2 and _hull.flipped != (direction_x < 0.0):
		_hull.flipped = direction_x < 0.0
	_motor.set_level(_current_speed / speed)
	queue_redraw()

## Turns for home when it has strayed too far, then keeps that heading if the
## water ahead is clear, or swings to whichever side is.
func _choose_heading() -> void:
	if global_position.distance_to(_home) > roam_radius:
		_wanted_heading = (_home - global_position).angle()
	if _is_open_water(_wanted_heading):
		return
	for turn: float in [AVOID_ANGLE, -AVOID_ANGLE, AVOID_ANGLE * 2.0, -AVOID_ANGLE * 2.0]:
		if _is_open_water(_wanted_heading + turn):
			_wanted_heading += turn
			return
	_wanted_heading += PI

func _is_open_water(heading: float) -> bool:
	for reach: float in [LOOK_AHEAD * 0.5, LOOK_AHEAD]:
		var ahead := global_position + Vector2.from_angle(heading) * reach
		if not _terrain.is_in_water(_terrain.to_local(ahead)):
			return false
	return true

## A V of white water trailing off the stern, longer the faster it goes.
func _draw() -> void:
	if _current_speed < 5.0:
		return
	var back := -1.0 if _hull.flipped else 1.0
	var stern := Vector2(-66.0 * back, 0.0)
	var length := 120.0 * _current_speed / speed
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			stern + Vector2(0.0, -6.0 * side), stern + Vector2(-length * back, 18.0 * side), stern + Vector2(-length * back * 0.8, 26.0 * side),
		]), WAKE)
