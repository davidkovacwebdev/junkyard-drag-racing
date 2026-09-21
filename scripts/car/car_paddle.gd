class_name CarPaddle
extends CarWheel
## A "wheel" that isn't a wheel. Instead of rolling, it swings back and
## forth around its mount like a boat paddle stroking water. Each
## backward stroke scoops the ground and shoves the chassis forward, so
## a paddle car lurches ahead in pulses rather than rolling smoothly.
##
## The mount sits at the MIDDLE of the shaft (the "oarlock"): a long
## handle sticks up past the roof while the blade reaches the ground, so
## the whole thing visibly sways above the car as it rows. The swing is
## forced directly inside _integrate_forces exactly the way CarWheel
## forces spin — same solver-proof trick — except the angle tracks a
## sine wave instead of a ramp, so the part swings instead of turning.
## The origin is left untouched, so real contacts and the PinJoint2D
## still resolve normally.
##
## No two strokes match: depth and cadence re-roll every half swing, the
## blade drifts on a slow random wobble, and each paddle starts at its
## own phase — so a car's paddles never row in lockstep. That
## irregularity is deliberate; it's what makes the car feel hand-paddled
## instead of motorised. The shove is applied at the blade (well below
## the chassis) rather than the centre of mass, so every power stroke
## also noses the car up a little, the way a real low push would.
##
## CarAssembler writes the engine's power into `target_angular_velocity`
## for every wheel; a paddle reads that as its STROKE RATE instead of a
## roll speed, so a bigger engine paddles faster and shoves harder.

## How far the blade swings to either side of hanging straight down.
@export var swing_angle: float = deg_to_rad(46.0)

## Engine power -> swing phase rate (rad/s). ~2.5 turns the starter V6's
## 3.5 power into a brisk paddling cadence (~1.4 strokes/second).
@export var stroke_rate_scale: float = 2.5

## Forward shove, in force units, at the peak of a power stroke, scaled by
## engine power raised to `power_exponent` below.
@export var thrust: float = 1000.0

## Engine power is raised to this before it becomes paddle force. Kept
## well below 1.0 on purpose: one stroke always digs in with roughly the
## same shove (a blade can only push so much ground), so engine size
## mostly buys CADENCE — more strokes per second — rather than a harder
## push per stroke. That also keeps weak engines paddling instead of
## stalling out.
@export var power_exponent: float = 0.2

## How much each stroke's depth and cadence vary from the last.
## 0 = a perfectly even, robotic stroke; higher = sloppier paddling.
@export var wonkiness: float = 0.35

## Slow angular drift (radians) of the blade around its stroke arc.
@export var wobble: float = deg_to_rad(7.0)

## Seconds a wobble target holds before re-rolling.
@export var wobble_interval: float = 0.45

## Seconds to ease the swing in from hanging straight down on spawn.
@export var intro_time: float = 0.4

## Stroke phase, advanced by engine power. sin() -> swing angle.
var _phase: float = 0.0

var _rng := RandomNumberGenerator.new()
var _stroke_index: int = -1
var _amp: float = 1.0
var _amp_target: float = 1.0
var _rate_mul: float = 1.0
var _rate_mul_target: float = 1.0
var _wobble: float = 0.0
var _wobble_target: float = 0.0
var _wobble_timer: float = 0.0
var _intro: float = 0.0

## ---- Physics-free preview (the world map's CarView) --------------------
## A race paddle reads engine power for its cadence (see the class docs), but
## the map's car has no engine and no physics at all. Out there the car's own
## movement sets the beat instead: one full back-and-forth per
## `stroke_distance` pixels travelled, so it rows in proportion to the ground
## it covers and settles to hanging straight down the moment it stops.

## World pixels of travel per full stroke on the map. Tuned to about the
## starter V6's race cadence (~1.4 strokes a second flat out).
@export var stroke_distance: float = 300.0

## Preview-only swing state, deliberately kept apart from the physics
## `_phase`/`_amp` so showing the car on the map can't disturb a race.
## `_visual_amp` is how much of the full swing to show: 0 hangs the blade
## straight down, 1 gives it the whole arc.
var _visual_phase: float = 0.0
var _visual_amp: float = 0.0

func _ready() -> void:
	super()
	_rng.randomize()
	# Start mid-swing so a car's paddles never row in lockstep — true of the
	# map's preview too, or a two-paddle car would row like a machine.
	_phase = _rng.randf() * TAU
	_visual_phase = _rng.randf() * TAU
	_wobble_target = _rng.randf_range(-wobble, wobble)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Frozen = decoration in a preview (the world map's CarView). The swing
	# belongs to animate_visual() there, so don't read engine power that isn't
	# coming and park the blade back at 0 underneath it.
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

	# Each half swing is one stroke: re-roll how deep and how fast it is,
	# so no two strokes land the same way.
	var stroke := int(_phase / PI)
	if stroke != _stroke_index:
		_stroke_index = stroke
		_amp_target = 1.0 + _rng.randf_range(-wonkiness, wonkiness)
		_rate_mul_target = 1.0 + _rng.randf_range(-wonkiness, wonkiness)

	# Ease toward the rolled values instead of snapping to them, so the
	# blade never teleports mid-swing.
	var blend := clampf(4.0 * step, 0.0, 1.0)
	_amp = lerpf(_amp, _amp_target, blend)
	_rate_mul = lerpf(_rate_mul, _rate_mul_target, blend)

	_wobble_timer -= step
	if _wobble_timer <= 0.0:
		_wobble_timer = wobble_interval * _rng.randf_range(0.6, 1.4)
		_wobble_target = _rng.randf_range(-wobble, wobble)
	_wobble = lerpf(_wobble, _wobble_target, clampf(3.0 * step, 0.0, 1.0))

	var rate := absf(target_angular_velocity) * stroke_rate_scale * _rate_mul
	_phase = fmod(_phase + rate * step, TAU)

	var swing := swing_angle * _amp * _intro
	var angle := sin(_phase) * swing + _wobble * _intro
	var stroke_speed := cos(_phase)        # -1..1; sign is the swing direction
	var angular_velocity := stroke_speed * swing * rate

	# Force the swing while preserving the resolved origin, so the blade
	# still collides and the joint still holds it to the chassis.
	state.transform = Transform2D(angle, state.transform.get_origin())
	state.angular_velocity = angular_velocity

	# Back-stroke (angle increasing) is the power stroke: the blade sweeps
	# the ground backward, so drive the chassis forward. The forward
	# recovery stroke coasts, so it doesn't cancel the push out.
	if stroke_speed > 0.0 and chassis != null and is_instance_valid(chassis):
		var power := absf(target_angular_velocity)
		var push := Vector2(thrust * pow(power, power_exponent) * stroke_speed, 0.0)
		# Shove at the blade, ~25px down the shaft — below the chassis's
		# centre of mass, so the car noses up on each power stroke.
		var blade_world: Vector2 = state.transform * Vector2(0.0, 25.0)
		chassis.apply_force(push, blade_world - chassis.global_position)

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
