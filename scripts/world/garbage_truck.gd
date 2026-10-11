class_name GarbageTruck
extends CharacterBody2D
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
##
## It isn't locked to its road: it has its own 2D velocity and steers toward
## a point `lookahead_distance` ahead along its route, only ever changing
## that velocity at `steer_acceleration`. So the player can ram it, shove it
## off the road or lean on it, and it drifts back onto its route on its own
## once let go. `collision_mask = 1` so it's blocked by the same world
## obstacles the player is (buildings, props, the shore) as well as the
## player's car itself, which also sits on layer 1.
##
## It also carries the town's mail. During "Special Delivery" Grandpa's
## package is on board: every hard ram counts toward the quest's
## `count_goal`, and every second the player leans on the horn nearby
## toward its `horn_goal_seconds`. Once both are done the package falls off
## the back (an ItemPickup). While that's on, the truck shows on the map as "Garbage
## Truck", the quest's `objective_place`.

@export var speed: float = 260.0
## Junction radius: when the road it's on runs out, any other road with an
## end within this distance counts as "connects here" and gets a chance to be
## driven onto instead of just turning around in place.
@export var hop_radius: float = 90.0
## Junction exits that turn sharper than this off the way the truck arrives
## are skipped. A road leaving a fork almost alongside the one it came in on
## is a hairpin the truck can't make, and it ends up circling the junction.
@export var max_junction_turn: float = deg_to_rad(120.0)
## Same resolution convention PlayerCar/TrashSpawner use: the exported path
## first, falling back to searching the scene for any RoadNetwork.
@export var roads_path: NodePath = ^"../../Roads"
@export var skid_marks_path: NodePath = ^"../../SkidMarks"

@export_group("Tilt")
## Leans less than the player's car — it's a heavier vehicle.
@export var tilt_max_angle: float = deg_to_rad(5.0)
@export var tilt_response: float = 6.0

@export_group("Skid marks")
## The truck skids whenever it's moving this far off the way it wants to go —
## a sharp junction turn, or sliding after being shoved.
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

@export_group("Steering")
## How far ahead along its route the truck aims. Longer rejoins the road in
## a wider, lazier curve after being knocked off it.
@export var lookahead_distance: float = 220.0
## The most the truck can change its own velocity per second. Low enough that
## a hit actually knocks it around before it gets itself back on course.
@export var steer_acceleration: float = 420.0

@export_group("Collision")
## Rough "how heavy is this truck" figure, weighed against the car's summed
## part masses (see PlayerCar._compute_car_mass()) to decide how much of a
## ram or a push the truck actually takes.
@export var mass: float = 160.0
## How quickly a sustained push drags the truck along, before the mass share.
@export var push_response: float = 14.0
@export var honk_cooldown: float = 3.0
## A shove at least this fast, or ending up this far off its route, earns
## the player an annoyed honk.
@export var honk_min_impact_speed: float = 120.0
@export var honk_off_route_distance: float = 110.0

@export_group("Grandpa's package")
## A ram only counts toward knocking the package loose when the car hits
## the truck at least this fast.
@export var ram_min_speed: float = 140.0
## Rams closer together than this count once, so one crunch isn't three.
@export var ram_cooldown: float = 0.6
## Honking only counts with the car at most this far from the truck.
@export var horn_range: float = 450.0

const PACKAGE_QUEST := preload("res://quests/special_delivery.tres")
const PACKAGE := preload("res://items/grandpas_package.tres")
## Where the hit count floats up from, above the truck's box.
const RAM_TEXT_LIFT := 150.0

@onready var _visual: CarView = $Visual as CarView

var _road_network: RoadNetwork = null
var _skid_marks: SkidMarksLayer = null
var _rng := RandomNumberGenerator.new()

## One RoadTrack per drivable road, built once from the network's decimated
## polylines. The full-fidelity ones carry a point every 5 px, and walking
## those from the start each physics frame cost several ms on a long road.
var _tracks: Array[RoadTrack] = []
var _current_road: RoadTrack = null
## Arc length along _current_road of the point closest to the truck.
var _travelled: float = 0.0
var _forward: bool = true
## Where the route continues after _current_road runs out — picked as soon as
## the lookahead first spills past its end, so the aim point flows around the
## junction instead of pinning to the road's last vertex.
var _next_road: RoadTrack = null
var _next_forward: bool = true

var _facing_right: bool = true
var _tilt: float = 0.0
var _last_move_dir: Vector2 = Vector2.RIGHT
var _skid_last_stamp: Array = []

var _collect_timer: float = 0.0
var _drop_timer: float = 0.0
var _honk_timer: float = 0.0
var _in_contact_last_frame: bool = false
var _in_contact_this_frame: bool = false
var _ram_timer: float = 0.0
var _package_orb: ItemPickup = null
var _marker: MinimapMarker = null
var _player_car: PlayerCar = null

func _ready() -> void:
	_rng.randomize()
	_road_network = _resolve_roads()
	_skid_marks = _resolve_skid_marks()
	_build_visual()
	_setup_engine_sound()
	_drop_timer = _rng.randf_range(drop_check_interval_min, drop_check_interval_max)
	if _road_network != null:
		_road_network.ensure_built()
		for road in _road_network.get_draw_polylines():
			if road.size() >= 2:
				_tracks.append(RoadTrack.new(road))
		_pick_new_road()
		if _current_road != null:
			_travelled = _rng.randf_range(0.0, _current_road.length)
			global_position = _current_road.sample(_travelled)

func _build_visual() -> void:
	var body := PartDatabase.load_part_data(
			"res://scenes/world/garbage_truck/garbage_truck_body.tscn") as BodyPartData
	var wheel := PartDatabase.load_part_data(
			"res://scenes/parts/wheels/wheel_standard.tscn") as WheelPartData
	var model := CarModelData.new()
	model.body = body
	model.wheels = [wheel, wheel]
	_visual.build_from(model)
	_visual.fit_collision($CollisionShape2D)

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
	if _current_road == null:
		return
	_advance_along_road(delta)

	var facing_sign := 1.0 if _facing_right else -1.0
	_update_tilt(delta, facing_sign)
	_visual.animate_wheels(_roll_distance(delta, facing_sign), delta)

	_collect_timer -= delta
	if _collect_timer <= 0.0:
		_collect_timer = collect_check_interval
		_try_collect_nearby_bin()
		_update_marker()

	_count_horn(delta)

	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer = _rng.randf_range(drop_check_interval_min, drop_check_interval_max)
		_maybe_drop_loot()

func _advance_along_road(delta: float) -> void:
	_honk_timer -= delta
	_ram_timer -= delta
	_in_contact_last_frame = _in_contact_this_frame
	_in_contact_this_frame = false

	_travelled = _current_road.closest_travelled(global_position, _travelled, lookahead_distance * 2.0)
	if _reached_next_road():
		_switch_to_next_road()

	var aim := _aim_point()
	var desired_dir := (aim - global_position).normalized()
	velocity = velocity.move_toward(desired_dir * speed, steer_acceleration * delta)

	if desired_dir.x > 0.01:
		_facing_right = true
	elif desired_dir.x < -0.01:
		_facing_right = false
	var facing_scale := 1.0 if _facing_right else -1.0
	if _visual.scale.x != facing_scale:
		_visual.scale.x = facing_scale
		_visual.mirror_collision($CollisionShape2D)

	var move_dir := velocity.normalized() if velocity.length() > 1.0 else _last_move_dir
	var skidding: bool = (
			velocity.length() > 60.0
			and absf(desired_dir.angle_to(move_dir)) > skid_angle_threshold)
	_last_move_dir = move_dir
	_update_skid_marks(skidding)

	var collision := move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.slide(collision.get_normal())
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))

	var off_route := global_position.distance_to(_current_road.sample(_travelled))
	if off_route > honk_off_route_distance:
		_try_honk()

## The point `lookahead_distance` further along the route, spilling onto
## _next_road (chosen on demand) once it runs past this road's end.
func _aim_point() -> Vector2:
	if _lookahead_spill() > 0.0 and _next_road == null:
		_choose_next_road()
	var spill := _lookahead_spill()
	if spill <= 0.0:
		var ahead := _travelled + lookahead_distance if _forward else _travelled - lookahead_distance
		return _current_road.sample(ahead)
	var next_length := _next_road.length
	var on_next := clampf(spill if _next_forward else next_length - spill, 0.0, next_length)
	return _next_road.sample(on_next)

## How far the lookahead runs past the end of the current road (≤ 0 while
## it's still on it).
func _lookahead_spill() -> float:
	var remaining := _current_road.length - _travelled if _forward else _travelled
	return lookahead_distance - remaining

## Prefer another road whose end sits within `hop_radius` of where this one
## runs out — a real junction — picked at random. A dead end instead turns
## the truck around on this same road right away, so it swings back before
## the end rather than nosing into it.
func _choose_next_road() -> void:
	var end_point := _road_end_point()
	var arrival_dir := _current_road.direction_at_end(not _forward)
	var candidates: Array[Dictionary] = []
	for track in _tracks:
		if track == _current_road:
			continue
		var forward: bool
		if track.first_point().distance_to(end_point) <= hop_radius:
			forward = true
		elif track.last_point().distance_to(end_point) <= hop_radius:
			forward = false
		else:
			continue
		var leaving_dir := -track.direction_at_end(forward)
		if absf(arrival_dir.angle_to(leaving_dir)) <= max_junction_turn:
			candidates.append({"road": track, "forward": forward})
	if candidates.is_empty():
		_forward = not _forward
		return
	var chosen: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_next_road = chosen["road"]
	_next_forward = chosen["forward"]

## Junction roads can meet anywhere within `hop_radius` of each other, so
## the handover happens once the truck is nearer the next road's entry than
## this road's end, not only when it literally reaches the end.
func _reached_next_road() -> bool:
	if _next_road == null:
		return false
	var entry := _next_road.first_point() if _next_forward else _next_road.last_point()
	var remaining := _current_road.length - _travelled if _forward else _travelled
	return remaining <= 20.0 \
			or global_position.distance_to(entry) <= global_position.distance_to(_road_end_point())

func _road_end_point() -> Vector2:
	return _current_road.last_point() if _forward else _current_road.first_point()

func _switch_to_next_road() -> void:
	_current_road = _next_road
	_forward = _next_forward
	_travelled = 0.0 if _forward else _current_road.length
	_next_road = null

## Called every physics frame the player's car is touching the truck (see
## PlayerCar._notify_garbage_truck_contact()). `pressing_velocity` is what the
## car is trying to drive at, `contact_normal` points from the truck toward
## the car. Only the part of the push aimed into the truck counts, so a
## sideswipe shoves it sideways and a rear-ender shoves it forward. The first
## frame of contact lands as a mass-weighted impulse (the ram); every frame
## after drags it along at a mass-weighted rate (the lean), which the truck's
## own steering keeps fighting.
func set_contact_push(pressing_velocity: Vector2, contact_normal: Vector2, other_mass: float) -> void:
	_in_contact_this_frame = true
	var push_dir := -contact_normal
	var push_speed := pressing_velocity.dot(push_dir)
	var gap := push_speed - velocity.dot(push_dir)
	if gap <= 0.0:
		return
	if not _in_contact_last_frame and gap >= ram_min_speed:
		_count_ram()
	var share := other_mass / (other_mass + mass)
	var step := share if not _in_contact_last_frame \
			else 1.0 - exp(-push_response * share * get_physics_process_delta_time())
	velocity += push_dir * gap * step
	if not _in_contact_last_frame and gap * share >= honk_min_impact_speed:
		_try_honk()

## Whether Grandpa's package is still on board and the player is after it.
func _wants_package() -> bool:
	var id := PACKAGE_QUEST.id
	return Quests.has_quest(id) and not Quests.is_ready(id) \
			and not Inventory.has_item(PACKAGE.id) and not is_instance_valid(_package_orb)

## A hard ram while the package is on board: one more toward the quest's
## count, floated up over the truck. Once the rams are all in, more of them
## just nag the player to honk.
func _count_ram() -> void:
	if _ram_timer > 0.0 or not _wants_package():
		return
	_ram_timer = ram_cooldown
	var id := PACKAGE_QUEST.id
	var goal := PACKAGE_QUEST.count_goal
	Sfx.play_at(&"car_whack", global_position, -4.0, 0.08)
	if Quests.count_of(id) >= goal:
		# Both done already (a reload since): the package falls off now.
		if not _try_drop_package():
			_float_text("Now honk at it!")
		return
	var hits := Quests.add_count(id)
	if not _try_drop_package():
		_float_text("%d / %d" % [hits, goal] if hits < goal else "Now honk at it!")

## The player leaning on the horn near the truck while the package is on
## board: the seconds add up toward the quest's horn goal, a count floats up
## each whole second, and the truck honks back at the end.
func _count_horn(delta: float) -> void:
	if not is_instance_valid(_player_car):
		_player_car = get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	if _player_car == null or not _player_car.is_honking() \
			or _player_car.global_position.distance_to(global_position) > horn_range:
		return
	var id := PACKAGE_QUEST.id
	var goal := PACKAGE_QUEST.horn_goal_seconds
	var before := Quests.horn_time_of(id)
	if before >= goal or not _wants_package():
		return
	var after := Quests.add_horn_time(id, delta)
	if floori(after) == floori(before):
		return
	if after < goal:
		_float_text("Honk %d / %d" % [floori(after), int(goal)])
		return
	# Fed up, the truck honks right back.
	_honk_timer = 0.0
	_try_honk()
	if not _try_drop_package():
		_float_text("Now ram it!")

## Drops the package once the quest's rams and honking are both done.
func _try_drop_package() -> bool:
	var id := PACKAGE_QUEST.id
	if Quests.count_of(id) < PACKAGE_QUEST.count_goal \
			or Quests.horn_time_of(id) < PACKAGE_QUEST.horn_goal_seconds:
		return false
	_drop_package()
	_float_text("Something fell off!")
	return true

func _float_text(text: String) -> void:
	var parent := get_parent()
	if parent != null:
		Pickup.spawn_callout(parent, global_position + Vector2(0.0, -RAM_TEXT_LIFT), text)

## Grandpa's package flies off the back of the box onto the road. It waits
## there however long the player takes (no fading away with the quest item).
func _drop_package() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var orb := ItemPickup.new()
	orb.configure(PACKAGE)
	orb.persistent = true
	parent.add_child(orb)
	var back := -_last_move_dir if _last_move_dir != Vector2.ZERO else Vector2.LEFT
	orb.launch(global_position + Vector2(0.0, -90.0), global_position + back * 170.0, 70.0, 0.55)
	_package_orb = orb
	Sfx.play_at(&"cardboard_crumple", global_position, -2.0, 0.05)
	_honk_timer = 0.0
	_try_honk()

## Puts the truck on the map (as the quest's "Garbage Truck") while the
## player is hunting it for the package, and takes it off again after.
func _update_marker() -> void:
	var wanted := _wants_package()
	if wanted and _marker == null:
		_marker = MinimapMarker.new()
		_marker.kind = MinimapMarker.Kind.GARBAGE_TRUCK
		_marker.place_name_override = "Garbage Truck"
		add_child(_marker)
	elif not wanted and _marker != null:
		_marker.remove_from_group(MinimapMarker.GROUP)
		_marker.queue_free()
		_marker = null

func _try_honk() -> void:
	if _honk_timer > 0.0:
		return
	_honk_timer = honk_cooldown
	Sfx.play_at(&"truck_honk", global_position, -6.0)

func _pick_new_road() -> void:
	var usable: Array[RoadTrack] = []
	for track in _tracks:
		if track.length > 200.0:
			usable.append(track)
	if usable.is_empty():
		return
	_current_road = usable[_rng.randi_range(0, usable.size() - 1)]
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
		var pool := _first_filled([PartDatabase.junk_wheels, PartDatabase.junk_bodies, PartDatabase.junk_engines])
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

## A road polyline with the arc length at each of its points, so sampling
## and closest-point lookups binary-search to the right segment instead of
## walking from the road's start.
class RoadTrack:
	var points: PackedVector2Array
	var distances := PackedFloat32Array()
	var length := 0.0

	func _init(road_points: PackedVector2Array) -> void:
		points = road_points
		distances.resize(points.size())
		for i in range(1, points.size()):
			length += points[i - 1].distance_to(points[i])
			distances[i] = length

	func first_point() -> Vector2:
		return points[0]

	func last_point() -> Vector2:
		return points[points.size() - 1]

	## Which way the road points as it runs out of its start or end, sampled
	## a short way in so a single jittery vertex doesn't skew it.
	func direction_at_end(at_start: bool) -> Vector2:
		var reach := minf(60.0, length)
		if at_start:
			return sample(reach).direction_to(first_point())
		return sample(length - reach).direction_to(last_point())

	## Point `distance` along the road, clamped to its ends.
	func sample(distance: float) -> Vector2:
		if distance <= 0.0:
			return points[0]
		if distance >= length:
			return last_point()
		var i := _segment_at(distance)
		var segment := distances[i + 1] - distances[i]
		if segment <= 0.0:
			return points[i]
		return points[i].lerp(points[i + 1], (distance - distances[i]) / segment)

	## Arc length of the point closest to `position`, only looking within
	## `window` of `around` so a road that doubles back past itself can't make
	## the truck's progress jump to the wrong stretch.
	func closest_travelled(position: Vector2, around: float, window: float) -> float:
		var best_distance := INF
		var best_travelled := around
		var first := _segment_at(around - window)
		var last := _segment_at(around + window)
		for i in range(first, last + 1):
			var a := points[i]
			var b := points[i + 1]
			var segment := distances[i + 1] - distances[i]
			if segment <= 0.0:
				continue
			var t := clampf((position - a).dot(b - a) / (segment * segment), 0.0, 1.0)
			var distance := position.distance_squared_to(a.lerp(b, t))
			if distance < best_distance:
				best_distance = distance
				best_travelled = distances[i] + t * segment
		return best_travelled

	## Index of the segment containing arc length `distance`, clamped.
	func _segment_at(distance: float) -> int:
		return clampi(distances.bsearch(distance, true) - 1, 0, points.size() - 2)

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
