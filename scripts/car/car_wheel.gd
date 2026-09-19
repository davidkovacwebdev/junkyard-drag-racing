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

## Rotation speed (rad/s) this wheel's motor targets. Positive spins the
## wheel clockwise, which rolls the car toward +x (forward/right).
var target_angular_velocity: float = 0.0

## Torque limit, expressed as max change in spin speed per second.
var motor_accel: float = 20.0

var _drive_speed: float = 0.0

func _ready() -> void:
	if part_data != null:
		mass = part_data.mass
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if target_angular_velocity == 0.0:
		return
	var step := state.get_step()
	_drive_speed = move_toward(_drive_speed, target_angular_velocity, motor_accel * step)
	var new_rotation := state.transform.get_rotation() + _drive_speed * step
	state.transform = Transform2D(new_rotation, state.transform.get_origin())
	state.angular_velocity = _drive_speed
