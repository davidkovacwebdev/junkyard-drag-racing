class_name YardDog
extends Node2D
## A scruffy yard dog lying by its kennel. When the car drives past within
## `notice_radius` it jumps up and chases it, running alongside and barking
## (`dog_bark`), until the car outruns it, stops for a while, or drags it past
## `leash_radius` from home. Then it trots back and lies down again.
## Origin on the ground under its feet so it Y-sorts against the car; home is
## wherever it starts.

enum State { RESTING, CHASING, RETURNING }

const FUR := Color(0.62, 0.46, 0.3)
const EAR := Color(0.36, 0.25, 0.16)
const COLLAR := Color(0.7, 0.2, 0.16)

@export var notice_radius: float = 650.0
@export var leash_radius: float = 1300.0
@export var chase_speed: float = 560.0
@export var trot_speed: float = 170.0

const MIN_CAR_SPEED := 90.0
## Further than this behind the car and it gives up.
const OUTRUN_DISTANCE := 700.0
## How long it barks at a stopped car before losing interest.
const BORED_TIME := 3.0
const REST_COOLDOWN := 1.5
## Where it runs relative to the car: a bit behind and off to one side.
const RUN_BEHIND := 90.0
const RUN_BESIDE := 80.0
const STEERING := 8.0
const BARK_INTERVAL := Vector2(0.45, 0.9)
const BARK_DB := -6.0
const STRIDE_RATE := 0.06
const WAG_RATE := 9.0

var _state := State.RESTING
var _home := Vector2.ZERO
var _player: Node2D
var _velocity := Vector2.ZERO
var _facing := 1.0
var _side := 1.0
var _bark_timer := 0.0
var _bark_pulse := 0.0
var _bored := 0.0
var _cooldown := 0.0
var _stride := 0.0
var _time := 0.0

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	_home = global_position
	_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D

func _process(delta: float) -> void:
	_time += delta
	_bark_pulse = maxf(0.0, _bark_pulse - delta * 6.0)
	match _state:
		State.RESTING:
			_rest(delta)
		State.CHASING:
			_chase(delta)
		State.RETURNING:
			_run_toward(_home, trot_speed, delta)
			if global_position.distance_to(_home) < 8.0:
				global_position = _home
				_velocity = Vector2.ZERO
				_state = State.RESTING
				_cooldown = REST_COOLDOWN
	if absf(_velocity.x) > 20.0:
		_facing = signf(_velocity.x)
	_stride += _velocity.length() * delta * STRIDE_RATE
	queue_redraw()

func _rest(delta: float) -> void:
	_cooldown -= delta
	if _player == null or _cooldown > 0.0:
		return
	var car_velocity: Vector2 = _player.get("velocity")
	if car_velocity.length() >= MIN_CAR_SPEED and _player.global_position.distance_to(global_position) < notice_radius:
		_state = State.CHASING
		_bored = 0.0
		_bark_timer = 0.0
		_side = signf(car_velocity.orthogonal().dot(global_position - _player.global_position))
		if _side == 0.0:
			_side = 1.0

func _chase(delta: float) -> void:
	var car_velocity: Vector2 = _player.get("velocity")
	var car_heading := car_velocity.normalized() if car_velocity.length() > 1.0 else Vector2.RIGHT * _facing
	var target := _player.global_position - car_heading * RUN_BEHIND + car_heading.orthogonal() * RUN_BESIDE * _side
	_run_toward(target, chase_speed, delta)
	_bored = _bored + delta if car_velocity.length() < MIN_CAR_SPEED else 0.0
	_bark_timer -= delta
	if _bark_timer <= 0.0:
		_bark_timer = randf_range(BARK_INTERVAL.x, BARK_INTERVAL.y)
		_bark_pulse = 1.0
		Sfx.play_at(&"dog_bark", global_position, BARK_DB, 0.1)
	var outrun := global_position.distance_to(_player.global_position) > OUTRUN_DISTANCE
	if outrun or _bored > BORED_TIME or global_position.distance_to(_home) > leash_radius:
		_state = State.RETURNING

func _run_toward(target: Vector2, top_speed: float, delta: float) -> void:
	var wanted := (target - global_position).limit_length(top_speed)
	if (target - global_position).length() < 30.0:
		wanted *= (target - global_position).length() / 30.0
	_velocity = _velocity.lerp(wanted, 1.0 - exp(-STEERING * delta))
	global_position += _velocity * delta

## Shadow, then two legs, tail, body, belly shade, head with its snout, the
## floppy dark ear and a red collar, all facing `_facing`. Lying down it
## drops onto its belly and hides its legs; running, the legs swing and the
## body bounces; barking jerks the head up.
func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 36.0, 7.0), UiPalette.SHADOW)
	var lying := _state == State.RESTING
	var running := _velocity.length() > 30.0
	var bounce := -absf(sin(_stride * PI)) * 6.0 if running else 0.0
	var drop := 18.0 if lying else 0.0
	draw_set_transform(Vector2(0.0, bounce + drop), 0.0, Vector2(_facing, 1.0))
	if not lying:
		var swing := sin(_stride * PI) * 10.0 if running else 0.0
		draw_colored_polygon(FlatProps.sliver(Vector2(-18.0, -24.0), Vector2(-18.0 - swing, -bounce), 8.0), FUR.darkened(0.2))
		draw_colored_polygon(FlatProps.sliver(Vector2(18.0, -24.0), Vector2(18.0 + swing, -bounce), 8.0), FUR.darkened(0.2))
	var wag := sin(_time * WAG_RATE) * 10.0
	draw_colored_polygon(FlatProps.sliver(Vector2(-26.0, -40.0), Vector2(-44.0, -58.0 + wag), 7.0), FUR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30.0, -44.0), Vector2(22.0, -48.0), Vector2(28.0, -22.0), Vector2(-28.0, -20.0),
	]), FUR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29.0, -28.0), Vector2(27.0, -28.0), Vector2(28.0, -22.0), Vector2(-28.0, -20.0),
	]), FUR.darkened(0.18))
	var head := Vector2(0.0, -10.0 * _bark_pulse)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(18.0, -62.0), head + Vector2(36.0, -68.0), head + Vector2(44.0, -58.0),
		head + Vector2(60.0, -54.0), head + Vector2(60.0, -42.0), head + Vector2(38.0, -40.0), head + Vector2(20.0, -44.0),
	]), FUR)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(22.0, -64.0), head + Vector2(36.0, -66.0), head + Vector2(30.0, -40.0),
	]), EAR)
	draw_colored_polygon(FlatProps.sliver(Vector2(16.0, -50.0), Vector2(22.0, -34.0), 7.0), COLLAR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
