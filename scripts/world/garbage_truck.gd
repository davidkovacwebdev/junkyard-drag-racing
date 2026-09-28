class_name GarbageTruck
extends Node2D
## An autonomous garbage truck that wanders the road network all on its own —
## same visual rig (CarView), tilt, wheel-roll and skid-mark tricks as
## PlayerCar, just driven by a road-following routine instead of WASD, and a
## bit slower than the player's own car.
##
## Before noon it's just traffic: driving its route, nothing more. From noon
## on (see `collect_start_hour`) it also picks off any full roadside bin its
## route happens to pass close enough to, quietly — that loot is gone, not
## dropped for the player, since the whole reason WorldState refills the city
## every morning is that the player and the truck are both working the same
## bins. Separately, and rarely, it drops a bit of its own load on the road —
## almost always scrap, very occasionally a real part.

@export var speed: float = 260.0
## Junction radius: when the road it's on runs out, any other road with an
## end within this distance counts as "connects here" and gets a chance to be
## driven onto instead of just turning around in place.
@export var hop_radius: float = 90.0
## Same resolution convention PlayerCar/TrashSpawner use: the exported path
## first, falling back to searching the scene for any RoadNetwork.
@export var roads_path: NodePath = ^"../../Roads"
@export var skid_marks_path: NodePath = ^"../../SkidMarks"

@export_group("Tilt")
## Leans less than the player's car — it's a heavier vehicle.
@export var tilt_max_angle: float = deg_to_rad(5.0)
@export var tilt_response: float = 6.0

@export_group("Skid marks")
## A sharp junction turn counts as a skid the same way a player's sudden
## direction change does; this truck can't brake or accelerate its way into
## one; it's always exactly cruising speed, so the only trigger it needs is
## "the road just bent hard".
@export var skid_angle_threshold: float = deg_to_rad(35.0)
@export var skid_mark_color: Color = Color(0.05, 0.05, 0.05, 0.55)
@export var skid_mark_width: float = 7.0
@export var skid_mark_min_gap: float = 14.0
@export var skid_mark_hold_time: float = 2.0
@export var skid_mark_fade_time: float = 3.0

@export_group("Collecting")
## Hour (24h clock) the truck starts emptying full bins it passes. Before
## this it's just driving.
@export var collect_start_hour: float = 12.0
## How close a full bin needs to be to get picked up. Generous — bins sit on
## the shoulder, well clear of the road centreline this truck actually
## drives, so this stands in for a truck-length reach/arm rather than the
## truck literally touching it.
@export var collect_radius: float = 170.0
@export var collect_check_interval: float = 0.5

@export_group("Drops")
@export var drop_check_interval_min: float = 18.0
@export var drop_check_interval_max: float = 32.0
## Chance, each check, that the truck drops something at all. Most of the
## time nothing falls.
@export_range(0.0, 1.0) var drop_chance: float = 0.16
## Of the drops that do happen, the odds it's a real part instead of scrap —
## rare on top of already-rare.
@export_range(0.0, 1.0) var part_share_of_drops: float = 0.08
@export var scrap_pickup_scene: PackedScene = preload("res://scenes/world/scrap_pickup.tscn")
@export var part_pickup_scene: PackedScene = preload("res://scenes/world/part_pickup.tscn")
## Quieter than the player's own -12dB (see the sound-design skill's level
## table) — this is background traffic, not the car you're driving.
@export var engine_volume_db: float = -18.0

@onready var _visual: CarView = $Visual as CarView

var _road_network: RoadNetwork = null
var _skid_marks: SkidMarksLayer = null
var _rng := RandomNumberGenerator.new()

var _current_road: PackedVector2Array = PackedVector2Array()
var _current_road_length: float = 0.0
var _travelled: float = 0.0
var _forward: bool = true

var velocity: Vector2 = Vector2.ZERO
var _facing_right: bool = true
var _tilt: float = 0.0
var _last_move_dir: Vector2 = Vector2.RIGHT
var _skid_last_stamp: Array = []

var _collect_timer: float = 0.0
var _drop_timer: float = 0.0

func _ready() -> void:
	_rng.randomize()
	_road_network = _resolve_roads()
	_skid_marks = _resolve_skid_marks()
	_build_visual()
	_setup_engine_sound()
	_drop_timer = _rng.randf_range(drop_check_interval_min, drop_check_interval_max)
	if _road_network != null:
		_road_network.ensure_built()
		_pick_new_road()
		if not _current_road.is_empty():
			_travelled = _rng.randf_range(0.0, _current_road_length)
			global_position = _sample_along(_current_road, _travelled)[0]

func _build_visual() -> void:
	var body := PartDatabase.load_part_data(
			"res://scenes/world/garbage_truck/garbage_truck_body.tscn") as BodyPartData
	var wheel := PartDatabase.load_part_data(
			"res://scenes/parts/wheels/wheel_tractor.tscn") as WheelPartData
	var model := CarModelData.new()
	model.body = body
	model.wheels = [wheel, wheel]
	_visual.build_from(model)

## A plain, constant hum — the truck never changes speed, so there's no rpm
## to chase like the player's engine has. Positional (EngineSound is an
## AudioStreamPlayer2D), so it fades in and out as the truck passes by.
func _setup_engine_sound() -> void:
	var profile := EngineSoundProfile.for_engine(null)
	if profile == null:
		return
	var engine_sound := EngineSound.new()
	engine_sound.profile = profile
	engine_sound.volume_db = engine_volume_db
	engine_sound.rpm = 0.4
	engine_sound.throttle = 1.0
	add_child(engine_sound)

func _physics_process(delta: float) -> void:
	if _road_network == null or _current_road.is_empty():
		return
	_advance_along_road(delta)

	var facing_sign := 1.0 if _facing_right else -1.0
	_update_tilt(delta, facing_sign)
	_visual.animate_wheels(_roll_distance(delta, facing_sign), delta)

	_collect_timer -= delta
	if _collect_timer <= 0.0:
		_collect_timer = collect_check_interval
		_try_collect_nearby_bin()

	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer = _rng.randf_range(drop_check_interval_min, drop_check_interval_max)
		_maybe_drop_loot()

## Moves `speed * delta` along the current road's arc length, hopping to a
## connecting road (or turning around) once it runs off either end.
func _advance_along_road(delta: float) -> void:
	var step := speed * delta
	_travelled += step if _forward else -step
	if _forward and _travelled >= _current_road_length:
		_handle_road_end(_current_road[_current_road.size() - 1])
	elif not _forward and _travelled <= 0.0:
		_handle_road_end(_current_road[0])

	var sample := _sample_along(_current_road, clampf(_travelled, 0.0, _current_road_length))
	var point: Vector2 = sample[0]
	var tangent: Vector2 = sample[1]
	var move_dir := tangent if _forward else -tangent
	if move_dir.length_squared() <= 0.0:
		return

	velocity = move_dir * speed
	if move_dir.x > 0.01:
		_facing_right = true
	elif move_dir.x < -0.01:
		_facing_right = false
	_visual.scale.x = 1.0 if _facing_right else -1.0

	var skidding: bool = (
			velocity.length() > 1.0
			and absf(_last_move_dir.angle_to(move_dir)) > skid_angle_threshold)
	_last_move_dir = move_dir
	_update_skid_marks(skidding)

	global_position = point

## Reached the end of the current road. Prefer hopping onto another road
## whose own end sits within `hop_radius` of this point — a real junction —
## picked at random if more than one qualifies; otherwise just turn around
## and keep driving the same road the other way.
func _handle_road_end(end_point: Vector2) -> void:
	var roads := _road_network.get_road_polylines()
	var candidates: Array[Dictionary] = []
	for road in roads:
		if road == _current_road or road.size() < 2:
			continue
		if road[0].distance_to(end_point) <= hop_radius:
			candidates.append({"road": road, "forward": true})
		elif road[road.size() - 1].distance_to(end_point) <= hop_radius:
			candidates.append({"road": road, "forward": false})
	if candidates.is_empty():
		_forward = not _forward
		_travelled = clampf(_travelled, 0.0, _current_road_length)
		return
	var chosen: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_current_road = chosen["road"]
	_current_road_length = _polyline_length(_current_road)
	_forward = chosen["forward"]
	_travelled = 0.0 if _forward else _current_road_length

func _pick_new_road() -> void:
	var roads := _road_network.get_road_polylines()
	var usable: Array[PackedVector2Array] = []
	for road in roads:
		if _polyline_length(road) > 200.0:
			usable.append(road)
	if usable.is_empty():
		return
	_current_road = usable[_rng.randi_range(0, usable.size() - 1)]
	_current_road_length = _polyline_length(_current_road)
	_forward = true
	_travelled = 0.0

## Any full bin/dumpster (see TrashProp, group "trash") close enough right
## now gets emptied — quietly, no orbs spilled. The reward for a bin is
## either you get there first, or you catch this truck's own separate,
## rarer drops instead; it isn't both.
func _try_collect_nearby_bin() -> void:
	if DayNightCycle.get_hour() < collect_start_hour:
		return
	for node in get_tree().get_nodes_in_group(&"trash"):
		var prop := node as TrashProp
		if prop == null or not prop.filled:
			continue
		if prop.global_position.distance_to(global_position) <= collect_radius:
			prop.filled = false
			if not prop.loot_id.is_empty():
				WorldState.mark_emptied(prop.loot_id)
			Sfx.play_at(&"crane_clang", prop.global_position, -8.0)

## Rarely tips a bit of its own load out onto the road behind it — almost
## always scrap, very occasionally a real part. Purely a treat for whoever's
## driving behind it; it never affects what's in any bin.
func _maybe_drop_loot() -> void:
	if _rng.randf() >= drop_chance:
		return
	var drop_point := global_position - _last_move_dir * 60.0
	var orb: Pickup
	if _rng.randf() < part_share_of_drops:
		var pool := _first_filled([PartDatabase.wheels, PartDatabase.bodies, PartDatabase.engines])
		if pool.is_empty():
			return
		var part_orb := part_pickup_scene.instantiate() as PartPickup
		part_orb.configure(pool[_rng.randi_range(0, pool.size() - 1)])
		orb = part_orb
	else:
		var scrap_orb := scrap_pickup_scene.instantiate() as ScrapPickup
		scrap_orb.amount = _rng.randi_range(1, 3)
		orb = scrap_orb
	var parent := get_parent()
	if parent == null:
		orb.free()
		return
	parent.add_child(orb)
	orb.launch(global_position, drop_point, 26.0, 0.35)

static func _first_filled(pools: Array) -> Array:
	for pool in pools:
		if pool is Array and not (pool as Array).is_empty():
			return pool
	return []

## Lean into the vertical component of travel, same formula as PlayerCar's
## own _update_tilt — a road that dips or climbs tips the truck the same
## way a player's own W/S would.
func _update_tilt(delta: float, facing_sign: float) -> void:
	var target := clampf(velocity.y / maxf(speed, 1.0), -1.0, 1.0) * tilt_max_angle
	_tilt = lerpf(_tilt, target, 1.0 - exp(-tilt_response * delta))
	_visual.rotation = _tilt * facing_sign

func _roll_distance(delta: float, facing_sign: float) -> float:
	var spd := velocity.length()
	if spd <= 0.01:
		return 0.0
	var direction := 1.0 if velocity.x * facing_sign >= 0.0 else -1.0
	return spd * direction * delta

func _update_skid_marks(skidding: bool) -> void:
	if _skid_marks == null:
		return
	var mounts := _visual.get_wheel_mounts()
	if _skid_last_stamp.size() != mounts.size():
		_skid_last_stamp.resize(mounts.size())
	for i in mounts.size():
		if not skidding:
			_skid_last_stamp[i] = null
			continue
		var world_pos: Vector2 = _visual.to_global(mounts[i])
		var last: Variant = _skid_last_stamp[i]
		if last == null:
			_skid_last_stamp[i] = world_pos
			continue
		var last_pos: Vector2 = last
		if last_pos.distance_to(world_pos) >= skid_mark_min_gap:
			_spawn_skid_segment(last_pos, world_pos)
			_skid_last_stamp[i] = world_pos

func _spawn_skid_segment(a: Vector2, b: Vector2) -> void:
	var line := Line2D.new()
	line.width = skid_mark_width
	line.default_color = skid_mark_color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.add_point(_skid_marks.to_local(a))
	line.add_point(_skid_marks.to_local(b))
	_skid_marks.add_child(line)
	var tween := line.create_tween()
	tween.tween_interval(skid_mark_hold_time)
	tween.tween_property(line, "modulate:a", 0.0, skid_mark_fade_time)
	tween.tween_callback(line.queue_free)

static func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

## Point and unit tangent `distance` along `points`, clamped to the last
## segment's direction past the end. Same approach as
## TrashSpawner._sample_along().
static func _sample_along(points: PackedVector2Array, distance: float) -> Array:
	var travelled := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var segment := a.distance_to(b)
		if segment <= 0.0:
			continue
		if travelled + segment >= distance:
			var t := (distance - travelled) / segment
			return [a.lerp(b, t), (b - a) / segment]
		travelled += segment
	var last := points[points.size() - 1]
	var previous := points[points.size() - 2]
	return [last, (last - previous).normalized()]

## Same resolution convention as PlayerCar/TrashSpawner: the exported path
## first, falling back to searching the scene for any RoadNetwork.
func _resolve_roads() -> RoadNetwork:
	var node := get_node_or_null(roads_path)
	if node is RoadNetwork:
		return node
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is RoadNetwork:
			return current
		for child in current.get_children():
			stack.append(child)
	return null

func _resolve_skid_marks() -> SkidMarksLayer:
	var node := get_node_or_null(skid_marks_path)
	if node is SkidMarksLayer:
		return node
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is SkidMarksLayer:
			return current
		for child in current.get_children():
			stack.append(child)
	return null
