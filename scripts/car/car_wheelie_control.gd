class_name CarWheelieControl
extends Node
## Keeps a strong engine from standing a sensible car on its tail. The motors
## push their torque back into the body, which lifts the nose. While the front
## wheel is off the ground, a rear one is on it and the nose is rising or
## already tilted up from the ground under it, every motor's torque fades out,
## and it comes back once the nose is down. Tilt is measured from the ground,
## not the world, so a hill climb isn't a wheelie. A wacky enough car (a jet on
## a bicycle) still flips: this only fades the motors, it can't hold a body
## down.

## Shared with CarAssembler, which drops a wheel from it when the wheel breaks.
var wheels: Array[CarWheel] = []
var body: CarBody

## Share of full torque cut / restored per second.
const CUT_RATE := 12.0
const RESTORE_RATE := 3.0
## Nose-up spin (rad/s) that counts as still rising rather than a bump, once
## the nose is at least RISING_TILT off the ground (the slope steepening under
## a hill climber turns the body too, but doesn't tilt it off the ground).
const RISING_SPIN := 0.3
const RISING_TILT := 0.12
## Nose-up tilt (rad) from the ground under the rear wheel that counts as
## already up.
const NOSE_UP_ANGLE := 0.35

var _torque_scale := 1.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(body) or wheels.size() < 2:
		return
	var drive_direction := _drive_direction()
	if drive_direction == 0.0:
		return
	var front: CarWheel = null
	var front_x := -INF
	for wheel in wheels:
		if not is_instance_valid(wheel):
			continue
		var forward_x := body.to_local(wheel.global_position).x * drive_direction
		if forward_x > front_x:
			front_x = forward_x
			front = wheel
	var rear: CarWheel = null
	for wheel in wheels:
		if is_instance_valid(wheel) and wheel != front and wheel.get_contact_count() > 0:
			rear = wheel
	var popping_wheelie := false
	if front != null and rear != null and front.get_contact_count() == 0:
		var tilt := rear.ground_normal.angle_to(-body.global_transform.y)
		var nose_tilt := -tilt * drive_direction
		popping_wheelie = nose_tilt > NOSE_UP_ANGLE \
				or (nose_tilt > RISING_TILT and body.angular_velocity * drive_direction < -RISING_SPIN)
	if popping_wheelie:
		_torque_scale = move_toward(_torque_scale, 0.0, CUT_RATE * delta)
	else:
		_torque_scale = move_toward(_torque_scale, 1.0, RESTORE_RATE * delta)
	for wheel in wheels:
		if is_instance_valid(wheel):
			wheel.torque_scale = _torque_scale

func _drive_direction() -> float:
	for wheel in wheels:
		if is_instance_valid(wheel) and wheel.target_angular_velocity != 0.0:
			return signf(wheel.target_angular_velocity)
	return 0.0
