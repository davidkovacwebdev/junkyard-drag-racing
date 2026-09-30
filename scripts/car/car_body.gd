class_name CarBody
extends RigidBody2D
## Physics body for a car's BODY part. Wheels hang off this on sprung
## suspension at the body's "WheelMount*" Marker2D children (see
## CarAssembler._suspend_wheel). Normal driving
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

## The body's lamps, in child order. Empty for bodies without any.
func get_headlight_mounts() -> Array[HeadlightMount]:
	var mounts: Array[HeadlightMount] = []
	for child in get_children():
		if child is HeadlightMount:
			mounts.append(child)
	return mounts

## Returns this body's "EngineMount" marker — the spot on this body's art
## where an installed engine belongs (a car's hood, a fridge's top, a
## boat's stern, ...). Null if the body declares none.
func get_engine_mount() -> Marker2D:
	for child in get_children():
		if child is Marker2D and child.name.begins_with("EngineMount"):
			return child
	return null

## Snaps an installed engine (or other mount decoration) onto this body's
## EngineMount so it sits where the body's art expects it instead of on
## the body's origin. Engines are authored with their origin at their
## mounting base (+y down, body extending up), so no extra offset is
## needed. Falls back to leaving the engine at its own position when the
## body has no mount. An engine that has to fit itself around the body (the
## horse walks out in front of it) gets `attach_to_body()` called afterwards.
func place_engine(engine: Node2D) -> void:
	var mount := get_engine_mount()
	if mount != null:
		engine.position = mount.position
		engine.rotation = mount.rotation
	if engine.has_method("attach_to_body"):
		engine.call("attach_to_body", self)
