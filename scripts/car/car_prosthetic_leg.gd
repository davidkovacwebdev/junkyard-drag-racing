class_name CarProstheticLeg
extends CarWheel
## A "wheel" that's a prosthetic leg. It never rolls: it walks. Each step it
## reaches forward, plants its foot on whatever is under it (the track, a
## crate, a rival's roof), then drags the car up to and past the foot before
## lifting and swinging forward again with its stiff, clunky knee.
##
## While planted, a spring holds the hip up at `standing_height` above the
## foot and a pull drags the chassis forward. The pull pushes back on whatever
## the foot is standing on, so walking on a rival shoves it backwards. Its only
## collision is a bumper at the knee, for when the car sags onto it.
##
## The leg's thigh, shin and foot are posed with two-bone IK every frame, knee
## pointing forward. A car with one leg and one wheel limps and drags. Several
## legs on one car share one gait: the first one leads and each next leg trails
## it by `gait_offset` of a step, so they never drift apart and rock a narrow
## car over.

@export var thigh_length: float = 26.0
@export var shin_length: float = 28.0
## Hip-to-foot distance the spring holds while the foot is planted.
@export var standing_height: float = 44.0
## How far ahead of the hip the foot reaches out to plant.
@export var step_reach: float = 24.0
## How high the foot lifts mid-swing.
@export var step_lift: float = 12.0
## Share of each step the foot spends planted.
@export var stance_fraction: float = 0.62
## Steps per second per unit of engine power.
@export var cadence_per_power: float = 0.35
@export var support_stiffness: float = 3000.0
@export var support_damping: float = 160.0
## Forward drag while planted, in force units, scaled by engine power raised
## to `power_exponent` and fading out near top speed.
@export var drag_force: float = 6000.0
@export var power_exponent: float = 0.3
## Top speed in px/s per unit of engine power.
@export var top_speed_per_power: float = 32.0
## Random wobble in each step's length and timing, so it walks with a limp.
@export var limp: float = 0.3
## World pixels of travel per step on the map.
@export var map_step_distance: float = 140.0
## Share of a step each extra leg on the car trails the one before it.
@export var gait_offset: float = 0.2

var _rng := RandomNumberGenerator.new()
var _phase: float = 0.0
var _step_rate_multiplier: float = 1.0
var _step_reach_multiplier: float = 1.0
var _is_planted: bool = false
var _planted_body: CollisionObject2D
var _planted_point_on_body: Vector2
var _previous_hip_height: float = 0.0
var _lift_off_foot: Vector2
var _foot: Vector2
var _excluded_bodies: Array[RID] = []
var _gait_leader: CarProstheticLeg
var _gait_position: int = 0

@onready var _thigh: Node2D = $Thigh
@onready var _shin: Node2D = $Shin
@onready var _foot_art: Node2D = $Foot

func _ready() -> void:
	super()
	_rng.randomize()
	_phase = _rng.randf()
	_foot = Vector2(0.0, standing_height)
	_lift_off_foot = _foot

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if freeze or chassis == null or not is_instance_valid(chassis):
		return
	var step := state.get_step()
	state.transform = Transform2D(chassis.rotation, state.transform.get_origin())
	state.angular_velocity = chassis.angular_velocity
	var hip := state.transform.get_origin()
	var to_local := state.transform.affine_inverse()
	var drive_direction := signf(target_angular_velocity)
	if drive_direction == 0.0:
		_unplant()
		_pose(Vector2(0.0, standing_height), 1.0)
		return

	var power := absf(target_angular_velocity)
	var previous_phase := _phase
	_advance_phase(power * cadence_per_power * step)
	var in_stance := _phase < stance_fraction
	var stance_started := in_stance and (previous_phase >= stance_fraction or previous_phase > _phase)

	if stance_started:
		_try_plant(state, hip, drive_direction)
	if _is_planted and (not in_stance or not is_instance_valid(_planted_body)):
		_unplant()

	if _is_planted:
		var planted_world := _planted_body.global_transform * _planted_point_on_body
		_foot = to_local * planted_world
		if _foot.length() > thigh_length + shin_length:
			_unplant()
		else:
			_drag(state, hip, planted_world, drive_direction, power)
	if not _is_planted:
		_previous_hip_height = standing_height
		var swing_progress := 1.0
		if not in_stance:
			swing_progress = (_phase - stance_fraction) / (1.0 - stance_fraction)
		var target := Vector2(step_reach * _step_reach_multiplier * drive_direction, standing_height)
		_foot = _lift_off_foot.lerp(target, swing_progress) + Vector2(0.0, -step_lift * sin(PI * swing_progress))
	_pose(_foot, drive_direction)

## The gait leader walks at its own limping pace; every other leg on the car
## follows the leader's phase, trailing it by its place in the gait.
func _advance_phase(phase_speed: float) -> void:
	if _gait_leader == null or not is_instance_valid(_gait_leader) or _gait_leader.chassis != chassis:
		_join_gait()
	if _gait_leader == self:
		_phase += phase_speed * _step_rate_multiplier
		if _phase >= 1.0:
			_phase -= 1.0
			_step_rate_multiplier = 1.0 + _rng.randf_range(-limp, limp)
			_step_reach_multiplier = 1.0 + _rng.randf_range(-limp, limp)
		return
	_phase = fposmod(_gait_leader._phase - gait_offset * _gait_position, 1.0)
	_step_reach_multiplier = _gait_leader._step_reach_multiplier

## Follows the first leg still attached to this car, and trails it by how
## many legs come before this one.
func _join_gait() -> void:
	_gait_leader = null
	_gait_position = 0
	for sibling in get_parent().get_children():
		if sibling == self:
			break
		if sibling is CarProstheticLeg and sibling.chassis == chassis:
			if _gait_leader == null:
				_gait_leader = sibling
			_gait_position += 1
	if _gait_leader == null:
		_gait_leader = self

func _try_plant(state: PhysicsDirectBodyState2D, hip: Vector2, drive_direction: float) -> void:
	var reach := thigh_length + shin_length
	var start := hip + state.transform.basis_xform(Vector2(step_reach * _step_reach_multiplier * drive_direction, 0.0))
	var query := PhysicsRayQueryParameters2D.create(start, start + state.transform.basis_xform(Vector2.DOWN) * reach)
	query.exclude = _car_bodies()
	var hit := state.get_space_state().intersect_ray(query)
	if hit.is_empty() or not (hit.collider is CollisionObject2D):
		return
	_planted_body = hit.collider
	_planted_point_on_body = _planted_body.global_transform.affine_inverse() * hit.position
	_previous_hip_height = hip.distance_to(hit.position)
	_is_planted = true
	RaceCarAudio.play(self, part_data.impact_sound, hit.position, -3.0)

func _unplant() -> void:
	_is_planted = false
	_planted_body = null
	_lift_off_foot = _foot

## Holds the hip up over the planted foot and hauls the car forward past it,
## shoving whatever the foot stands on the other way.
func _drag(state: PhysicsDirectBodyState2D, hip: Vector2, planted_world: Vector2, drive_direction: float, power: float) -> void:
	var foot_to_hip := hip - planted_world
	var hip_height := foot_to_hip.length()
	var height_speed := (hip_height - _previous_hip_height) / state.get_step()
	_previous_hip_height = hip_height
	var lift := maxf(0.0, support_stiffness * (standing_height - hip_height) - support_damping * height_speed)
	var support := foot_to_hip / maxf(hip_height, 0.001) * lift

	var top_speed := power * top_speed_per_power
	var forward_speed := chassis.linear_velocity.x * drive_direction
	var pull_share := clampf(1.0 - forward_speed / maxf(top_speed, 1.0), -1.0, 1.0)
	var pull := Vector2(drag_force * pow(power, power_exponent) * pull_share * drive_direction, 0.0)

	var total := support + pull
	chassis.apply_force(total, hip - chassis.global_position)
	if _planted_body is RigidBody2D:
		var stood_on := _planted_body as RigidBody2D
		stood_on.apply_force(-total, planted_world - stood_on.global_position)

func _car_bodies() -> Array[RID]:
	if _excluded_bodies.is_empty():
		for sibling in get_parent().get_children():
			if sibling is CollisionObject2D:
				_excluded_bodies.append(sibling.get_rid())
		for part in chassis.get_children():
			if part is CollisionObject2D:
				_excluded_bodies.append(part.get_rid())
	return _excluded_bodies

## Poses thigh, shin and foot so the foot lands on `foot` (leg-local), with
## the knee bending toward `drive_direction`.
func _pose(foot: Vector2, drive_direction: float) -> void:
	var reach := thigh_length + shin_length
	var distance := clampf(foot.length(), absf(thigh_length - shin_length) + 0.01, reach - 0.01)
	var along := foot.normalized() if foot.length() > 0.001 else Vector2.DOWN
	foot = along * distance
	var knee_offset := (thigh_length * thigh_length - shin_length * shin_length + distance * distance) / (2.0 * distance)
	var knee_height := sqrt(maxf(0.0, thigh_length * thigh_length - knee_offset * knee_offset))
	var knee_side := Vector2(-along.y, along.x)
	if knee_side.x * drive_direction < 0.0:
		knee_side = -knee_side
	var knee := along * knee_offset + knee_side * knee_height

	_thigh.rotation = _pointing_down_rotation(knee)
	_shin.position = knee
	_shin.rotation = _pointing_down_rotation(foot - knee)
	_foot_art.position = foot
	_foot_art.scale.x = drive_direction if drive_direction != 0.0 else 1.0

func _pointing_down_rotation(direction: Vector2) -> float:
	return direction.angle() - PI * 0.5

## Overrides CarWheel.animate_visual: on the map the leg walks in place, one
## step per `map_step_distance` travelled, and stands still when the car stops.
func animate_visual(distance: float, _delta: float) -> void:
	if absf(distance) < 0.0001:
		return
	var drive_direction := 1.0
	_phase = fmod(_phase + absf(distance) / map_step_distance, 1.0)
	var front := Vector2(step_reach * drive_direction, standing_height)
	var back := Vector2(-step_reach * drive_direction, standing_height)
	var foot: Vector2
	if _phase < stance_fraction:
		foot = front.lerp(back, _phase / stance_fraction)
	else:
		var swing_progress := (_phase - stance_fraction) / (1.0 - stance_fraction)
		foot = back.lerp(front, swing_progress) + Vector2(0.0, -step_lift * sin(PI * swing_progress))
	_pose(foot, drive_direction)
