class_name CarPogo
extends CarWheel
## A "wheel" that's a pogo stick. It never rolls: it hangs under its mount on
## a spring and bounces the car along in hops.
##
## The spring is a ray cast down the stick. Wherever the ray finds something
## (the track, a crate, a rival's roof) within `rest_length`, the spring pushes
## the chassis back up along the stick, like a raycast suspension. The engine
## pumps extra push into every extension, so each bounce ends higher than it
## started, until gravity and the car's weight balance it out. Spring and pump
## scale with the chassis's mass, so every body hops about the same height:
## unscaled, light bodies launched high enough to wreck themselves on landing.
##
## The stick leans forward, so every push has a forward part to it: that is
## the drive. The lean fades out near top speed. It only partly follows the chassis's tilt (`self_righting`), so
## a car landing nose-up hops backwards a bit and a bad landing can snowball
## into a flip. Its collision foot sits at the fully compressed spot and is
## only for bottoming out.

@export var rest_length: float = 46.0
## How far the foot can sink before the stick bottoms out on its hard foot.
@export var spring_travel: float = 22.0
## Spring, damping and pump are tuned for a chassis this heavy and scaled to
## the real one.
@export var reference_chassis_mass: float = 20.0
@export var stiffness: float = 5000.0
@export var spring_damping: float = 150.0
## Extra push, in force units, while the spring extends, scaled by engine
## power raised to `power_exponent`.
@export var pump_force: float = 40000.0
@export var power_exponent: float = 0.3
## Forward tilt of the stick while driving, in radians. It straightens up as
## the car nears its top speed and leans back past it, so the hops brake.
@export var lean: float = deg_to_rad(16.0)
## Top speed in px/s per unit of engine power.
@export var top_speed_per_power: float = 30.0
## 0 = the stick tilts fully with the chassis, 1 = it always points straight down.
@export var self_righting: float = 0.35
## A hop this deep (px of compression) or deeper boings at full volume.
@export var loudest_compression: float = 16.0
## World pixels of travel per bounce on the map.
@export var hop_distance: float = 140.0

var _compression: float = 0.0
var _deepest_compression: float = 0.0
var _excluded_bodies: Array[RID] = []
var _visual_phase: float = 0.0
var _visual_amount: float = 0.0
var _plunger_rest_positions: Dictionary = {}

@onready var _spring: Polygon2D = $Spring
@onready var _spring_length: float = _measure_height(_spring.polygon)
@onready var _plunger_parts: Array[Polygon2D] = [$Plunger, $Foot]

func _ready() -> void:
	super()
	for part in _plunger_parts:
		_plunger_rest_positions[part] = part.position

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if freeze or chassis == null or not is_instance_valid(chassis):
		return
	var step := state.get_step()
	var drive_direction := signf(target_angular_velocity)
	var top_speed := absf(target_angular_velocity) * top_speed_per_power
	var forward_speed := chassis.linear_velocity.x * drive_direction
	var lean_amount := clampf(1.0 - forward_speed / maxf(top_speed, 1.0), -1.0, 1.0)
	var angle := chassis.rotation * (1.0 - self_righting) + lean * lean_amount * drive_direction
	state.transform = Transform2D(angle, state.transform.get_origin())
	state.angular_velocity = chassis.angular_velocity

	var mount := state.transform.get_origin()
	var down := state.transform.basis_xform(Vector2.DOWN).normalized()
	var hit_distance := _ray_distance(state, mount, down)
	var previous_compression := _compression
	_compression = clampf(rest_length - hit_distance, 0.0, spring_travel)
	var compression_speed := (_compression - previous_compression) / step

	if _compression > 0.0:
		_deepest_compression = maxf(_deepest_compression, _compression)
		var push := stiffness * _compression + spring_damping * compression_speed
		if compression_speed < 0.0:
			push += pump_force * pow(absf(target_angular_velocity), power_exponent)
		push *= chassis.mass / reference_chassis_mass
		chassis.apply_force(-down * maxf(push, 0.0), mount - chassis.global_position)
	elif previous_compression > 0.0:
		_boing()
	_show_compression(_compression)

## How far down the stick the nearest thing is, or `rest_length` if nothing is.
func _ray_distance(state: PhysicsDirectBodyState2D, from: Vector2, down: Vector2) -> float:
	if _excluded_bodies.is_empty():
		for sibling in get_parent().get_children():
			if sibling is CollisionObject2D:
				_excluded_bodies.append(sibling.get_rid())
		for part in chassis.get_children():
			if part is CollisionObject2D:
				_excluded_bodies.append(part.get_rid())
	var query := PhysicsRayQueryParameters2D.create(from, from + down * rest_length)
	query.exclude = _excluded_bodies
	var hit := state.get_space_state().intersect_ray(query)
	if hit.is_empty():
		return rest_length
	return from.distance_to(hit.position)

func _boing() -> void:
	var depth := _deepest_compression
	_deepest_compression = 0.0
	if depth < 3.0:
		return
	var loudness := clampf(depth / loudest_compression, 0.25, 1.0)
	RaceCarAudio.play(self, &"pogo_boing", global_position, linear_to_db(loudness))

## Slides the plunger and foot up the stick and squashes the coil to match.
func _show_compression(compression: float) -> void:
	for part in _plunger_parts:
		part.position = _plunger_rest_positions[part] + Vector2(0.0, -compression)
	_spring.scale.y = maxf(0.2, (_spring_length - compression) / _spring_length)

func _measure_height(points: PackedVector2Array) -> float:
	var top := INF
	var bottom := -INF
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	return maxf(1.0, bottom - top)

## Overrides CarWheel.animate_visual: on the map the stick bounces in place,
## one squash per `hop_distance` travelled, and settles when the car stops.
func animate_visual(distance: float, delta: float) -> void:
	var moving := absf(distance) > 0.0001
	if moving:
		_visual_phase = fmod(_visual_phase + absf(distance) / hop_distance * TAU, TAU)
	_visual_amount = move_toward(_visual_amount, 1.0 if moving else 0.0, delta * 3.0)
	_show_compression(maxf(0.0, sin(_visual_phase)) * spring_travel * 0.6 * _visual_amount)
