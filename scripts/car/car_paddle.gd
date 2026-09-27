class_name CarPaddle
extends CarWheel
## A "wheel" that's a boat paddle. It never rolls: it sways side to side
## around its mount like an oar being sculled. A raycast down from the
## blade tip — the same "is anything actually under this" check
## CarPogo's spring and CarProstheticLeg's foot use — decides whether the
## current stroke actually connects; a stroke that finds nothing (the
## blade's swung out over a gap, mid-air off a jump) is just dead weight
## swinging, exactly like a real oar with nothing to dig into.
##
## The mount sits at the shaft's oarlock: the grip sticks up past the roof
## while the blade hangs down for the ground, sweeping through swing_angle
## to either side of hanging straight down. The back half of each swing
## (angle increasing) is the power stroke, sweeping the blade toward the
## stern; the front half recovers. No two strokes match — cadence re-rolls
## every half swing — so a car's paddles never row in lockstep.

@export var swing_angle: float = deg_to_rad(46.0)
## Stroke phase rate (rad/s of the sway itself) per unit of engine power.
@export var stroke_rate_per_power: float = 2.5
## How far past the blade tip the ground-contact raycast reaches.
@export var blade_reach: float = 42.0
## Local-space distance from the mount down the shaft to the blade tip,
## where the contact raycast starts from.
@export var blade_offset: float = 22.0
## Forward push, in force units, on a connecting power stroke, scaled by
## engine power raised to power_exponent and fading out near top speed.
@export var push_force: float = 22000.0
@export var power_exponent: float = 0.3
## Top speed in px/s per unit of engine power.
@export var top_speed_per_power: float = 38.0
## Random per-stroke variation in cadence, so no two strokes match.
@export var wonkiness: float = 0.3
## Seconds to ease the swing in from hanging straight down on spawn.
@export var intro_time: float = 0.4
## World pixels of travel per stroke, for the map preview.
@export var stroke_distance: float = 300.0

var _phase: float = 0.0
var _rng := RandomNumberGenerator.new()
var _stroke_index: int = -1
var _rate_mul: float = 1.0
var _rate_mul_target: float = 1.0
var _intro: float = 0.0
var _splashed_this_stroke: bool = false
var _excluded_bodies: Array[RID] = []

var _visual_phase: float = 0.0
var _visual_amp: float = 0.0

func _ready() -> void:
	super()
	_rng.randomize()
	_phase = _rng.randf() * TAU

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if freeze:
		return
	var step := state.get_step()

	if target_angular_velocity == 0.0:
		# Parked: hang straight down and wait to be asked to row.
		_phase = 0.0
		_stroke_index = -1
		_intro = 0.0
		state.transform = Transform2D(0.0, state.transform.get_origin())
		state.angular_velocity = 0.0
		return

	_intro = move_toward(_intro, 1.0, step / maxf(intro_time, 0.001))
	var power := absf(target_angular_velocity)
	var drive_direction := signf(target_angular_velocity)

	# Each half swing is one stroke: re-roll its cadence so no two strokes
	# land the same way.
	var stroke := int(_phase / PI)
	if stroke != _stroke_index:
		_stroke_index = stroke
		_rate_mul_target = 1.0 + _rng.randf_range(-wonkiness, wonkiness)
		_splashed_this_stroke = false
	_rate_mul = lerpf(_rate_mul, _rate_mul_target, clampf(4.0 * step, 0.0, 1.0))

	var rate := power * stroke_rate_per_power * _rate_mul
	_phase = fmod(_phase + rate * step, TAU)
	var swing := swing_angle * _intro
	var angle := sin(_phase) * swing
	state.transform = Transform2D(angle, state.transform.get_origin())
	state.angular_velocity = cos(_phase) * rate * swing

	if chassis == null or not is_instance_valid(chassis):
		return

	# Back-stroke only (angle increasing) is the power stroke; the forward
	# recovery stroke coasts, so it doesn't cancel the push out.
	if cos(_phase) <= 0.0:
		return

	var blade_world: Vector2 = state.transform * Vector2(0.0, blade_offset)
	if _ray_distance(state, blade_world, Vector2.DOWN) > blade_reach:
		return

	var top_speed := power * top_speed_per_power
	var forward_speed := chassis.linear_velocity.x * drive_direction
	var push_share := clampf(1.0 - forward_speed / maxf(top_speed, 1.0), 0.0, 1.0)
	var push := Vector2(push_force * pow(power, power_exponent) * push_share * drive_direction, 0.0)
	chassis.apply_force(push, blade_world - chassis.global_position)

	if not _splashed_this_stroke:
		_splashed_this_stroke = true
		RaceCarAudio.play(self, &"paddle_splash", blade_world, -6.0)

## How far below `from` the nearest thing is, or `blade_reach + 1.0` (a
## guaranteed miss) if nothing is within blade_reach.
func _ray_distance(state: PhysicsDirectBodyState2D, from: Vector2, direction: Vector2) -> float:
	if _excluded_bodies.is_empty():
		for sibling in get_parent().get_children():
			if sibling is CollisionObject2D:
				_excluded_bodies.append(sibling.get_rid())
		for part in chassis.get_children():
			if part is CollisionObject2D:
				_excluded_bodies.append(part.get_rid())
	var query := PhysicsRayQueryParameters2D.create(from, from + direction * blade_reach)
	query.exclude = _excluded_bodies
	var hit := state.get_space_state().intersect_ray(query)
	if hit.is_empty():
		return blade_reach + 1.0
	return from.distance_to(hit.position)

## Overrides CarWheel.animate_visual: a paddle doesn't roll, it rows. Distance
## converted straight into stroke phase means the cadence follows the car's
## speed for free, and the blade is always at a believable point of its arc
## rather than mid-turn like a wheel would be.
func animate_visual(distance: float, delta: float) -> void:
	var moving := absf(distance) > 0.0001
	if moving:
		_visual_phase = fmod(_visual_phase + distance / maxf(stroke_distance, 1.0) * TAU, TAU)
	# Ease in and out over intro_time, sharing the race rig's meaning for it: a
	# set-off doesn't snap the blade into full swing, and a stop parks it back
	# at hanging straight down instead of freezing it mid-stroke.
	_visual_amp = move_toward(_visual_amp, 1.0 if moving else 0.0, delta / maxf(intro_time, 0.001))
	rotation = sin(_visual_phase) * swing_angle * _visual_amp
