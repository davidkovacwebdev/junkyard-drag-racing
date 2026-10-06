class_name Bird
extends Node2D
## A gull on the beach or a crow in the graveyard. While sitting it hops,
## pecks and turns round now and then; when the car comes within its
## `scare_radius` it takes off with a `wing_flutter` (and usually its call)
## and flaps up and away from the car. It is removed once it has flown out of
## the camera's view, never while you can still see it.
##
## Origin is the ground point it sorts by. `perch_height` lifts it onto
## something (a tombstone top, the crypt roof, a branch) without changing that,
## so it still sorts with the thing it's sitting on. Spawned by GullSpawner
## and BirdRoost.

enum Species { GULL, CROW }

const BODY_COLORS := {Species.GULL: Color(0.88, 0.88, 0.84), Species.CROW: Color(0.17, 0.17, 0.19)}
const WING_COLORS := {Species.GULL: Color(0.55, 0.57, 0.6), Species.CROW: Color(0.1, 0.1, 0.12)}
const BEAK_COLORS := {Species.GULL: UiPalette.ACCENT_YELLOW, Species.CROW: Color(0.34, 0.34, 0.36)}
const CALLS := {Species.GULL: &"gull_cry", Species.CROW: &"crow_caw"}
## Chance it calls out as it takes off. Crows nearly always complain.
const CALL_CHANCE := {Species.GULL: 0.5, Species.CROW: 0.9}
const SCARE_RADII := {Species.GULL: 260.0, Species.CROW: 330.0}

const SCARE_CHECK_INTERVAL := 0.15
## A random pause before taking off, so a flock doesn't lift as one.
const TAKEOFF_DELAY := Vector2(0.0, 0.3)
const IDLE_INTERVAL := Vector2(1.2, 3.5)
const HOP_TIME := 0.28
const HOP_HEIGHT := 10.0
const HOP_DISTANCE := 14.0
const PECK_TIME := 0.35
const FLY_START_SPEED := 140.0
const FLY_TOP_SPEED := 340.0
const FLY_ACCELERATION := 260.0
const CLIMB_SPEED := 110.0
const FLAP_SPEED := 15.0
## How far past the edge of the view it has to be before it's removed.
const OFFSCREEN_MARGIN := 80.0
const FLUTTER_DB := -10.0
const CALL_DB := -8.0
## Above everything it flies over, which all sorts at z 0 in Sortables.
const FLYING_Z := 20

var species := Species.GULL
var perch_height := 0.0

var _player: Node2D
var _facing := 1.0
var _scare_check := 0.0
var _takeoff_in := -1.0
var _idle_wait := 0.0
var _hop := -1.0
var _peck := -1.0
var _flying := false
var _flight_direction := Vector2.ZERO
var _flight_speed := 0.0
var _altitude := 0.0
var _flap := 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	_facing = 1.0 if randf() < 0.5 else -1.0
	_idle_wait = randf_range(IDLE_INTERVAL.x, IDLE_INTERVAL.y)
	_flap = randf() * TAU

func _process(delta: float) -> void:
	if _flying:
		_fly(delta)
	else:
		_sit(delta)
	queue_redraw()

func _sit(delta: float) -> void:
	if _takeoff_in >= 0.0:
		_takeoff_in -= delta
		if _takeoff_in < 0.0:
			_take_off()
		return
	_scare_check -= delta
	if _scare_check <= 0.0:
		_scare_check = SCARE_CHECK_INTERVAL
		if _player != null and _player.global_position.distance_to(global_position) < SCARE_RADII[species]:
			_takeoff_in = randf_range(TAKEOFF_DELAY.x, TAKEOFF_DELAY.y)
			return
	if _hop >= 0.0:
		_hop += delta
		if perch_height <= 0.0:
			position.x += _facing * HOP_DISTANCE * delta / HOP_TIME
		if _hop >= HOP_TIME:
			_hop = -1.0
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
			_hop = 0.0
		1:
			_peck = 0.0
		2:
			_facing = -_facing

func _take_off() -> void:
	_flying = true
	z_index = FLYING_Z
	var away := Vector2.from_angle(randf() * TAU)
	if _player != null and _player.global_position != global_position:
		away = (global_position - _player.global_position).normalized()
	_flight_direction = (away.rotated(randf_range(-0.6, 0.6)) + Vector2(0.0, -0.4)).normalized()
	_flight_speed = FLY_START_SPEED
	if absf(_flight_direction.x) > 0.1:
		_facing = signf(_flight_direction.x)
	Sfx.play_at(&"wing_flutter", global_position, FLUTTER_DB)
	if randf() < CALL_CHANCE[species]:
		Sfx.play_at(CALLS[species], global_position, CALL_DB)

func _fly(delta: float) -> void:
	_flight_speed = minf(FLY_TOP_SPEED, _flight_speed + FLY_ACCELERATION * delta)
	position += _flight_direction * _flight_speed * delta
	_altitude += CLIMB_SPEED * delta
	_flap += FLAP_SPEED * delta
	if not CritterSpawner.view_rect(self).grow(OFFSCREEN_MARGIN).has_point(global_position + Vector2(0.0, -perch_height - _altitude)):
		queue_free()


## Shadow (only while sitting), then body, folded wing or two flapping wings,
## head and beak, all facing `_facing`. A hop lifts it, a peck dips the head.
func _draw() -> void:
	var lift := perch_height + _altitude
	if _hop >= 0.0:
		lift += sin(PI * _hop / HOP_TIME) * HOP_HEIGHT
	if not _flying:
		draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -perch_height), 15.0, 4.0), UiPalette.SHADOW)
	draw_set_transform(Vector2(0.0, -lift), 0.0, Vector2(_facing, 1.0))
	var body: Color = BODY_COLORS[species]
	var wing: Color = WING_COLORS[species]
	if _flying:
		draw_colored_polygon(_wing(-6.0, 22.0), wing.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22.0, -18.0), Vector2(-4.0, -24.0), Vector2(12.0, -22.0),
		Vector2(16.0, -12.0), Vector2(6.0, -5.0), Vector2(-10.0, -8.0),
	]), body)
	if _flying:
		draw_colored_polygon(_wing(2.0, 30.0), wing)
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-24.0, -19.0), Vector2(-4.0, -22.0), Vector2(8.0, -16.0), Vector2(-10.0, -11.0),
		]), wing)
	var dip := Vector2(4.0, 8.0) * sin(PI * _peck / PECK_TIME) if _peck >= 0.0 else Vector2.ZERO
	var head := Vector2(14.0, -27.0) + dip
	draw_colored_polygon(FlatProps.octagon(head, 7.0, 7.0), body)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(5.0, -3.0), head + Vector2(15.0, 0.0), head + Vector2(5.0, 3.0),
	]), BEAK_COLORS[species])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## One flapping wing from the shoulder, its tip `reach` above or below it as
## it beats. The far wing is drawn first, shorter and darker.
func _wing(shoulder_x: float, reach: float) -> PackedVector2Array:
	var tip := Vector2(shoulder_x - 8.0, -20.0 - reach * sin(_flap))
	return PackedVector2Array([
		Vector2(shoulder_x - 10.0, -20.0), Vector2(shoulder_x + 8.0, -20.0), tip,
	])
