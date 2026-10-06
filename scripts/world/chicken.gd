class_name Chicken
extends Node2D
## A farm chicken pottering about its `pen`: pecking, turning and strolling to
## a new spot. When the car comes near it panics and runs off flapping with a
## `chicken_cluck`; if the car actually clips it, it squawks (`chicken_squawk`),
## gets flung in an arc in a puff of feathers, lands and runs off. Once things
## calm down it walks back into the pen. Spawned by ChickenFlock. Origin on the
## ground under its feet so it Y-sorts against the car.

const FEATHERS := Color(0.9, 0.88, 0.82)
const COMB := Color(0.78, 0.18, 0.14)
const BEAK := UiPalette.ACCENT_YELLOW
## The drawing is laid out at a comfortable size and shrunk to chicken scale.
const DRAW_SCALE := 0.65

const SCARE_RADIUS := 240.0
const SCARE_MIN_CAR_SPEED := 40.0
const HIT_RADIUS := 50.0
const HIT_MIN_CAR_SPEED := 60.0
const HIT_COOLDOWN := 1.0
const PANIC_TIME := 1.6
const PANIC_SPEED := 260.0
const WALK_SPEED := 50.0
const STEERING := 5.0
const IDLE_INTERVAL := Vector2(0.8, 2.6)
const PECK_TIME := 0.3
const FLING_SPEED := 0.8
const FLING_LIFT := 420.0
const GRAVITY := 1400.0
const FLAP_SPEED := 30.0
const STRIDE_RATE := 0.08
const CLUCK_CHANCE := 0.35
const CLUCK_DB := -10.0
const SQUAWK_DB := -2.0
const FEATHER_COUNT := 4
const FEATHER_LIFE := 1.1

var pen := Rect2()

var _player: Node2D
var _velocity := Vector2.ZERO
var _facing := 1.0
var _panic := 0.0
var _hit_cooldown := 0.0
var _height := 0.0
var _rise_speed := 0.0
var _spin := 0.0
var _idle_wait := 0.0
var _peck := -1.0
var _stroll_to := Vector2.ZERO
var _strolling := false
var _stride := 0.0
var _flap := 0.0
## Each feather is [global position, velocity, age].
var _feathers: Array = []

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	_facing = 1.0 if randf() < 0.5 else -1.0
	_idle_wait = randf_range(IDLE_INTERVAL.x, IDLE_INTERVAL.y)

func _process(delta: float) -> void:
	_hit_cooldown -= delta
	_update_feathers(delta)
	if _height > 0.0 or _rise_speed > 0.0:
		_fly_through_air(delta)
	else:
		_check_car()
		if _panic > 0.0:
			_panic -= delta
			_flap += FLAP_SPEED * delta
			_steer(_velocity.normalized() * PANIC_SPEED, delta)
		elif not pen.has_point(global_position):
			_steer((pen.get_center() - global_position).normalized() * WALK_SPEED * 2.0, delta)
		else:
			_potter(delta)
	if absf(_velocity.x) > 10.0:
		_facing = signf(_velocity.x)
	_stride += _velocity.length() * delta * STRIDE_RATE
	queue_redraw()

func _check_car() -> void:
	if _player == null:
		return
	var car_velocity: Vector2 = _player.get("velocity")
	var to_chicken := global_position - _player.global_position
	var distance := to_chicken.length()
	if distance < HIT_RADIUS and car_velocity.length() > HIT_MIN_CAR_SPEED and _hit_cooldown <= 0.0:
		_get_hit(car_velocity)
	elif distance < SCARE_RADIUS and car_velocity.length() > SCARE_MIN_CAR_SPEED and _panic <= 0.0:
		_panic = PANIC_TIME
		var away := to_chicken.normalized() if distance > 1.0 else Vector2.from_angle(randf() * TAU)
		_velocity = away.rotated(randf_range(-0.7, 0.7)) * PANIC_SPEED
		if randf() < CLUCK_CHANCE:
			Sfx.play_at(&"chicken_cluck", global_position, CLUCK_DB, 0.15)

func _get_hit(car_velocity: Vector2) -> void:
	_hit_cooldown = HIT_COOLDOWN
	_velocity = car_velocity * FLING_SPEED + Vector2.from_angle(randf() * TAU) * 80.0
	_rise_speed = FLING_LIFT
	_height = 0.01
	_panic = PANIC_TIME
	Sfx.play_at(&"chicken_squawk", global_position, SQUAWK_DB, 0.1)
	for i in FEATHER_COUNT:
		var burst := Vector2.from_angle(randf() * TAU) * randf_range(80.0, 180.0)
		_feathers.append([global_position + Vector2(0.0, -30.0), burst + Vector2(0.0, -120.0), 0.0])

func _fly_through_air(delta: float) -> void:
	global_position += _velocity * delta
	_rise_speed -= GRAVITY * delta
	_height += _rise_speed * delta
	_spin += 12.0 * delta * _facing
	_flap += FLAP_SPEED * delta
	if _height <= 0.0:
		_height = 0.0
		_rise_speed = 0.0
		_spin = 0.0
		_velocity = _velocity.normalized() * PANIC_SPEED

func _potter(delta: float) -> void:
	if _strolling:
		_steer((_stroll_to - global_position).limit_length(WALK_SPEED), delta)
		if global_position.distance_to(_stroll_to) < 6.0:
			_strolling = false
		return
	_steer(Vector2.ZERO, delta)
	if _peck >= 0.0:
		_peck += delta
		if _peck >= PECK_TIME:
			_peck = -1.0
	_idle_wait -= delta
	if _idle_wait > 0.0:
		return
	_idle_wait = randf_range(IDLE_INTERVAL.x, IDLE_INTERVAL.y)
	match randi() % 3:
		0:
			_peck = 0.0
		1:
			_facing = -_facing
		2:
			_strolling = true
			var stroll := global_position + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0)
			_stroll_to = stroll.clamp(pen.position, pen.end)

func _steer(wanted: Vector2, delta: float) -> void:
	_velocity = _velocity.lerp(wanted, 1.0 - exp(-STEERING * delta))
	global_position += _velocity * delta

func _update_feathers(delta: float) -> void:
	for feather in _feathers:
		feather[2] += delta
		feather[1] = feather[1] * exp(-3.0 * delta) + Vector2(0.0, 60.0) * delta
		feather[0] += feather[1] * delta
	_feathers = _feathers.filter(func(feather) -> bool: return feather[2] < FEATHER_LIFE)

## Shadow, two legs, tail, body, the one wing (flapping when it panics), head,
## the red comb and beak, all facing `_facing`. Flung, it tumbles; a peck dips
## the head. The feather puff is drawn last, where the hit happened.
func _draw() -> void:
	var shadow_scale := clampf(1.0 - _height / 300.0, 0.4, 1.0)
	draw_colored_polygon(FlatProps.octagon(Vector2(2.0, 0.0), 15.0 * shadow_scale, 4.0 * shadow_scale), UiPalette.SHADOW)
	var moving := _velocity.length() > 20.0 and _height <= 0.0
	var bounce := -absf(sin(_stride * PI)) * 4.0 if moving else 0.0
	draw_set_transform(Vector2(0.0, -_height + bounce * DRAW_SCALE), _spin, Vector2(_facing, 1.0) * DRAW_SCALE)
	var swing := sin(_stride * PI) * 7.0 if moving else 0.0
	draw_colored_polygon(FlatProps.sliver(Vector2(-5.0, -16.0), Vector2(-5.0 - swing, -bounce), 5.0), BEAK.darkened(0.2))
	draw_colored_polygon(FlatProps.sliver(Vector2(5.0, -16.0), Vector2(5.0 + swing, -bounce), 5.0), BEAK.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14.0, -30.0), Vector2(-28.0, -46.0), Vector2(-20.0, -24.0),
	]), FEATHERS.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20.0, -30.0), Vector2(-10.0, -40.0), Vector2(10.0, -38.0),
		Vector2(18.0, -26.0), Vector2(8.0, -14.0), Vector2(-12.0, -14.0),
	]), FEATHERS)
	var wing_tip := Vector2(-14.0, -34.0 - 14.0 * sin(_flap)) if _panic > 0.0 or _height > 0.0 else Vector2(-12.0, -24.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, -32.0), Vector2(8.0, -28.0), wing_tip,
	]), FEATHERS.darkened(0.15))
	var dip := Vector2(4.0, 10.0) * sin(PI * _peck / PECK_TIME) if _peck >= 0.0 else Vector2.ZERO
	var head := Vector2(12.0, -44.0) + dip
	draw_colored_polygon(FlatProps.sliver(head + Vector2(-4.0, -8.0), head + Vector2(4.0, -10.0), 6.0), COMB)
	draw_colored_polygon(FlatProps.octagon(head, 8.0, 8.0), FEATHERS)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(6.0, -3.0), head + Vector2(15.0, 1.0), head + Vector2(6.0, 4.0),
	]), BEAK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for feather in _feathers:
		var center := to_local(feather[0])
		var tilt := Vector2.from_angle(feather[2] * 5.0) * 7.0
		draw_colored_polygon(FlatProps.sliver(center - tilt, center + tilt, 6.0), FEATHERS)
