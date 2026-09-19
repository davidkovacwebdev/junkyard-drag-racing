class_name CarBody
extends RigidBody2D
## Physics body for a car's BODY part. Wheels are pinned onto this via
## PinJoint2D at the body's "WheelMount*" Marker2D children. Normal driving
## is pushed entirely by its wheels' real ground friction transmitted back
## through those joints (see car_wheel.gd) — `boost_force` is a separate,
## optional continuous push RaceController applies once a car crosses the
## finish line, so it genuinely accelerates over the runway into the wall
## rather than getting an instant velocity snap.

@export var part_data: BodyPartData

var boost_force: float = 0.0

func _ready() -> void:
	if part_data != null:
		mass = part_data.mass
	can_sleep = false
	# The finish-line boost gets fast enough to cross the whole EndWall in
	# under one physics tick without this — continuous collision detection
	# keeps the wall an actual wall instead of something cars phase through.
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

func _physics_process(_delta: float) -> void:
	if boost_force != 0.0:
		apply_central_force(Vector2(boost_force, 0.0))

## Returns this body's WheelMount marker children, in child order.
func get_wheel_mounts() -> Array[Marker2D]:
	var mounts: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("WheelMount"):
			mounts.append(child)
	return mounts
