class_name Tumbleweed
extends Node2D
## A dry tumbleweed roaming the desert, bouncing and spinning as the wind rolls
## it left or right. Just before it would roll out of the desert (or into the
## sea) the wind swings round and it rolls back, so it stays inside the sand.
## Driving into it knocks it flying with a `tumbleweed_crunch`, then the wind
## takes it again; knocked out of the desert, it heads back for the nearest
## sand. It only fades out if it's knocked right into the sea. Spawned, and
## removed once far off screen, by TumbleweedSpawner. Origin on the ground under the ball so it
## Y-sorts against the car; the ball itself hops above it.

const DRY := Color(0.66, 0.54, 0.34)
const GAP := Color(0.36, 0.28, 0.17)

const FADE_TIME := 1.0
const HOP_RATE := 2.4
const GUST_RATE := 0.4
## How close the car has to get to hit it, and how fast it has to be going.
const HIT_RADIUS := 60.0
const HIT_MIN_SPEED := 60.0
const HIT_COOLDOWN := 0.6
const KICK_LIFT := 70.0
## How quickly a kick wears off and the tumbleweed is back to drifting.
const KICK_DRAG := 1.6
const TERRAIN_CHECK_INTERVAL := 0.3
## How far ahead it looks for the edge of the desert before turning back.
const LOOK_AHEAD := 160.0
## After turning it keeps going a while before it may turn again, so it can't
## dither on a corner of the desert.
const TURN_COOLDOWN := 2.0
## Most of the wind is sideways; this is how far it may tilt up or down.
const MAX_DRIFT_TILT := 0.35
const SAND_SEARCH_DIRECTIONS := 8
const CRUNCH_DB := -8.0

## Drift velocity the wind gives it.
var wind := Vector2(120.0, 30.0)
var terrain: TerrainNetwork

var _radius := 26.0
var _hop_height := 18.0
var _velocity := Vector2.ZERO
var _kick_lift := 0.0
var _spin := 0.0
var _age := 0.0
var _phase := 0.0
var _fading := false
var _hit_cooldown := 0.0
var _terrain_check := 0.0
var _turn_cooldown := 0.0
var _player: Node2D

func _ready() -> void:
	_radius = randf_range(20.0, 30.0)
	_hop_height = randf_range(12.0, 26.0)
	_phase = randf() * TAU
	_velocity = wind
	_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	modulate.a = 0.0

func _process(delta: float) -> void:
	_age += delta
	modulate.a = maxf(0.0, modulate.a - delta / FADE_TIME) if _fading else minf(1.0, modulate.a + delta / FADE_TIME)
	if _fading and modulate.a <= 0.0:
		queue_free()
		return

	var gust := 1.0 + 0.35 * sin(_age * TAU * GUST_RATE + _phase)
	_velocity = _velocity.lerp(wind * gust, 1.0 - exp(-KICK_DRAG * delta))
	_kick_lift = maxf(0.0, _kick_lift - KICK_LIFT * KICK_DRAG * delta)
	position += _velocity * delta
	_spin += _velocity.x * delta / _radius
	_phase += delta * TAU * HOP_RATE * (_velocity.length() / maxf(wind.length(), 1.0))
	_check_hit(delta)
	_check_terrain(delta)
	queue_redraw()

func _check_hit(delta: float) -> void:
	_hit_cooldown -= delta
	if _player == null or _hit_cooldown > 0.0:
		return
	var car_velocity: Vector2 = _player.get("velocity")
	if car_velocity.length() < HIT_MIN_SPEED or _player.global_position.distance_to(global_position) > HIT_RADIUS:
		return
	_hit_cooldown = HIT_COOLDOWN
	_velocity = car_velocity * 1.2 + wind
	_kick_lift = KICK_LIFT
	Sfx.play_at(&"tumbleweed_crunch", global_position, CRUNCH_DB)

func _check_terrain(delta: float) -> void:
	_turn_cooldown -= delta
	_terrain_check -= delta
	if terrain == null or _fading or _terrain_check > 0.0:
		return
	_terrain_check = TERRAIN_CHECK_INTERVAL
	if not terrain.is_on_land(terrain.to_local(global_position)):
		_fading = true
		return
	if _turn_cooldown > 0.0 or _is_sand(global_position + wind.normalized() * LOOK_AHEAD):
		return
	_turn_cooldown = TURN_COOLDOWN
	var heading := -signf(wind.x) if wind.x != 0.0 else 1.0
	if not _is_sand(global_position):
		heading = _sand_side()
	wind = Vector2(heading, randf_range(-MAX_DRIFT_TILT, MAX_DRIFT_TILT)).normalized() * wind.length()

func _is_sand(global_point: Vector2) -> bool:
	var point := terrain.to_local(global_point)
	return terrain.is_on_land(point) and terrain.biome_at(point) == TerrainBiome.Kind.DESERT

## Which way (-1 left, 1 right) the nearest desert lies, for a tumbleweed the
## car has knocked out of it. Keeps its current way if no sand is in reach.
func _sand_side() -> float:
	for i in SAND_SEARCH_DIRECTIONS:
		var direction := Vector2.from_angle(TAU * i / SAND_SEARCH_DIRECTIONS)
		if absf(direction.x) > 0.1 and _is_sand(global_position + direction * LOOK_AHEAD * 3.0):
			return signf(direction.x)
	return signf(wind.x) if wind.x != 0.0 else 1.0

## A ground shadow that shrinks as it bounces up, then the ball: a lumpy dry
## outline with a dark hollow middle and two sticks across it, all spinning
## together so the tumbling reads.
func _draw() -> void:
	var lift := absf(sin(_phase)) * _hop_height + _kick_lift
	var shadow_scale := clampf(1.0 - lift / 120.0, 0.5, 1.0)
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), _radius * shadow_scale, _radius * 0.3 * shadow_scale), UiPalette.SHADOW)
	var center := Vector2(0.0, -_radius - lift)
	draw_colored_polygon(_ball(center, _radius), DRY)
	draw_colored_polygon(_ball(center + Vector2(2.0, 2.0), _radius * 0.6), GAP)
	for stick_angle in [0.3, 2.1]:
		var along := Vector2.from_angle(_spin + stick_angle) * _radius * 0.85
		draw_colored_polygon(FlatProps.sliver(center - along, center + along, 6.0), DRY.darkened(0.12))

## A lumpy ten-sided ball whose bumps turn with the spin.
func _ball(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle := _spin + TAU * i / 10.0
		points.append(center + Vector2.from_angle(angle) * radius * (0.9 if i % 2 == 0 else 1.0))
	return points
