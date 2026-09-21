class_name CarWheel
extends RigidBody2D
## Physics body for a car's WHEEL part. This IS the car's drive: the
## wheel is a motor that forces its own rotation (torque-limited ramp to
## a target speed), and real ground friction against its actual polygon
## shape — round, square, a toilet bowl, whatever — converts that
## guaranteed rotation into the car's forward push through the
## PinJoint2D to the body.
##
## The rotation is forced directly inside _integrate_forces rather than
## via apply_torque/angular_velocity in _physics_process. That matters:
## a wheel with any flat resting face against a flat floor is a
## degenerate contact Godot's solver clamps to zero rotation no matter
## how much torque or target velocity you throw at it from the outside
## (confirmed empirically). Overriding the resolved transform inside
## _integrate_forces — the one hook that runs after the solver, giving
## us the final say — sidesteps that entirely, so wild non-round wheel
## shapes still work exactly like round ones: the wheel spins, and
## whatever normal/friction forces its actual silhouette generates
## against the ground are what push the car, bumps and all.

@export var part_data: WheelPartData

## The rigid body this wheel is jointed to, set by CarAssembler. Plain
## rolling wheels never need it — they push the car purely through
## ground friction — but a subclass like CarPaddle uses it to shove the
## chassis directly. Optional so a wheel scene still works standalone.
var chassis: RigidBody2D

## Rotation speed (rad/s) this wheel's motor targets. Positive spins the
## wheel clockwise, which rolls the car toward +x (forward/right).
var target_angular_velocity: float = 0.0

## Torque limit, expressed as max change in spin speed per second.
var motor_accel: float = 20.0

var _drive_speed: float = 0.0

## This wheel's rolling radius in its own authored (local) units, measured
## from its artwork the first time it's needed. Negative = not measured yet.
var _local_radius: float = -1.0

func _ready() -> void:
	if part_data != null:
		mass = part_data.mass
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# A frozen wheel is decoration, not physics: CarView freezes the ones on
	# the world map's car (it has no physics at all) and moves their art by
	# hand with animate_visual() instead. Driving them here as well would just
	# fight that.
	if freeze or target_angular_velocity == 0.0:
		return
	var step := state.get_step()
	_drive_speed = move_toward(_drive_speed, target_angular_velocity, motor_accel * step)
	var new_rotation := state.transform.get_rotation() + _drive_speed * step
	state.transform = Transform2D(new_rotation, state.transform.get_origin())
	state.angular_velocity = _drive_speed

## ---- Physics-free preview --------------------------------------------
## The world map's car is pure decoration (see CarView), so its wheels can't
## animate themselves the way a race wheel does from inside
## _integrate_forces. CarView calls animate_visual() by hand every frame
## instead, and that one method is all a wheel scene needs to implement to
## come to life out there: a plain wheel rolls, a paddle swings (CarPaddle
## overrides it). CarView looks the method up by name, so a part is free to
## not be a CarWheel at all.

## Animate this wheel over `distance` world pixels of travel along the car's
## facing (signed — the caller has already corrected for facing). `delta` is
## the frame time, for a wheel whose motion wants a clock instead of just
## ground covered.
##
## Wheel art is authored centred on the wheel's own origin, the same pivot the
## race rig's physics wheels turn on, so a plain `rotation` spins a wheel
## around its axle exactly where it sits on the car.
func animate_visual(distance: float, _delta: float) -> void:
	if distance == 0.0:
		return
	rotation += distance / visual_roll_radius()

## The radius this wheel is actually drawn at, which is what a *rolling* wheel
## has to divide by: how far a wheel turns depends on the radius it rolls on,
## not on the units its art happens to be authored in — and it's what keeps a
## chunky square wheel from spinning in lockstep with a thin bicycle one.
##
## The artwork measurement is cached; the scale is read live off the wheel's
## own global transform, so it tracks however this preview is being displayed
## (the world car is fitted to 90px, the garage draws at natural size) without
## anyone having to tell the wheel about it.
func visual_roll_radius() -> float:
	if _local_radius <= 0.0:
		var bounds := PartScale.measure_bounds(self)
		_local_radius = maxf(1.0, maxf(bounds.size.x, bounds.size.y) * 0.5)
	return _local_radius * maxf(absf(global_scale.x), 0.0001)
