class_name CarWheel
extends RigidBody2D
## Physics body for a car's WHEEL part. This IS the car's drive: an
## electric-style motor torques the wheel (full torque from a standstill,
## fading to none at its top spin speed) and pushes the same torque back
## into the chassis. Nothing moves the car but the friction the wheel's
## actual polygon shape — round, square, a toilet bowl, whatever — finds
## against the ground, so a wheel only turns as far as the car rolls
## unless the torque is more than its grip can hold, and then it spins.

@export var part_data: WheelPartData

## The rigid body this wheel is jointed to, set by CarAssembler. It takes
## the motor's reaction torque. Optional so a wheel scene still works
## standalone.
var chassis: RigidBody2D

## Rotation speed (rad/s) this wheel's motor targets. Positive spins the
## wheel clockwise, which rolls the car toward +x (forward/right).
var target_angular_velocity: float = 0.0

## Motor torque at a standstill. CarAssembler sets it from the engine.
var stall_torque: float = 0.0

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
	if freeze:
		return
	var target := _current_target_speed()
	if target == 0.0:
		return
	var torque := stall_torque * signf(target) * clampf(1.0 - state.angular_velocity / target, -1.0, 1.0)
	state.apply_torque(torque)
	if chassis != null:
		chassis.apply_torque(-torque)

## Knocks the wheel's spin down to `fraction_kept` of itself.
func lose_spin(fraction_kept: float) -> void:
	angular_velocity *= fraction_kept

## The spin speed the motor is heading for right now. A wheel with a mind of
## its own (the hamster wheel) overrides this; 0 lets the wheel roll freely.
func _current_target_speed() -> float:
	return target_angular_velocity

## ---- Physics-free preview --------------------------------------------
## The world map's car is pure decoration (see CarView), so its wheels can't
## animate themselves the way a race wheel does from inside
## _integrate_forces. CarView calls animate_visual() by hand every frame
## instead, and that one method is all a wheel scene needs to implement to
## come to life out there. CarView looks the method up by name, so a part
## is free to not be a CarWheel at all.

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
