class_name CarHydraulics
extends Node
## Lowrider hydraulics. Once the pump has recharged and every wheel is on the
## ground, the rams fire: the body is kicked straight up along its own up axis
## while the wheels stay planted, so the rams visibly shove the wheels out to
## the end of the body's `hydraulic_stroke` (CarAssembler lets the suspension
## drop that far). There the stroke runs out and drags the wheels off the
## ground after it, and the springs pull them back in mid-air. Each hop pops
## the nose up a little, like a lowrider showing off.
##
## The body's "HydraulicRam*" polygons are authored from their top end (the
## node's origin) straight down to the wheel's axle at rest, behind the wheel.
## Every frame each one is stretched and turned to reach its wheel's axle.

## Shared with CarAssembler, which drops a wheel from it when the wheel breaks.
var wheels: Array[CarWheel] = []
var body: CarBody

## Nose-up spin (rad/s) added on every hop, in the direction of travel.
const NOSE_POP_SPIN := 0.9
## Time on the ground after landing before the rams can fire again, so a hop
## doesn't re-trigger on the bounce. Skittering airborne for a moment at speed
## only drains it, it doesn't start it over.
const SETTLE_TIME := 0.25
## How far past its rim a wheel can be off the ground and still count as on it.
const GROUND_SLACK := 10.0
const RAM_PREFIX := "HydraulicRam"

var _recharge_left := 1.0
var _grounded_time := 0.0
var _wheel_radii := {}
var _excluded_bodies: Array[RID] = []
## Ram polygon -> [wheel it reaches, authored length].
var _rams := {}

func _ready() -> void:
	for child in body.get_children():
		if child is Polygon2D and child.name.begins_with(RAM_PREFIX):
			var wheel := _nearest_wheel(child.position)
			if wheel != null:
				_rams[child] = [wheel, _authored_length(child.polygon)]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(body) or body.freeze or body.part_data == null:
		return
	_stretch_rams()
	_recharge_left -= delta
	var grounded := _all_wheels_grounded()
	if grounded:
		_grounded_time += delta
	else:
		_grounded_time = maxf(0.0, _grounded_time - delta)
	if not grounded or _recharge_left > 0.0 or _grounded_time < SETTLE_TIME or _drive_direction() == 0.0:
		return
	_hop()

func _hop() -> void:
	_recharge_left = body.part_data.hydraulic_recharge_time
	_grounded_time = 0.0
	var up := -body.global_transform.y.normalized()
	var hop_velocity := up * body.part_data.hydraulic_hop_speed
	body.apply_central_impulse(hop_velocity * body.mass)
	body.angular_velocity -= NOSE_POP_SPIN * _drive_direction()
	RaceCarAudio.play(body, &"hydraulic_hop", body.global_position, -6.0)

func _all_wheels_grounded() -> bool:
	var any_wheel := false
	for wheel in wheels:
		if not is_instance_valid(wheel):
			continue
		any_wheel = true
		if not _wheel_on_ground(wheel):
			return false
	return any_wheel

## Rigid-body contact reports drop out on a rolling wheel, so this casts a short
## ray straight down from the axle instead.
func _wheel_on_ground(wheel: CarWheel) -> bool:
	if _excluded_bodies.is_empty():
		_excluded_bodies.append(body.get_rid())
		for other in wheels:
			_excluded_bodies.append(other.get_rid())
	var from := wheel.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2.DOWN * (_wheel_radius(wheel) + GROUND_SLACK))
	query.exclude = _excluded_bodies
	return not body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _stretch_rams() -> void:
	for ram: Polygon2D in _rams:
		var wheel = _rams[ram][0]
		if not is_instance_valid(wheel):
			ram.visible = false
			continue
		var reach := body.to_local((wheel as CarWheel).global_position) - ram.position
		ram.rotation = reach.angle() - PI * 0.5
		ram.scale.y = maxf(reach.length(), 1.0) / _rams[ram][1]

func _wheel_radius(wheel: CarWheel) -> float:
	if not _wheel_radii.has(wheel):
		_wheel_radii[wheel] = wheel.drive_radius()
	return _wheel_radii[wheel]

func _nearest_wheel(local_position: Vector2) -> CarWheel:
	var nearest: CarWheel = null
	var nearest_distance := INF
	for wheel in wheels:
		var distance := absf(body.to_local(wheel.global_position).x - local_position.x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = wheel
	return nearest

static func _authored_length(points: PackedVector2Array) -> float:
	var bottom := 0.0
	for point in points:
		bottom = maxf(bottom, point.y)
	return maxf(bottom, 1.0)

func _drive_direction() -> float:
	for wheel in wheels:
		if is_instance_valid(wheel) and wheel.target_angular_velocity != 0.0:
			return signf(wheel.target_angular_velocity)
	return 0.0
