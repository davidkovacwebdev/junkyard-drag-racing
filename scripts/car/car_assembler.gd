class_name CarAssembler
extends RefCounted
## Builds a physics-driven car at runtime from a body scene, an array of
## wheel scenes, and an engine scene. This is the one code path both the
## Phase 1 test rigs and the later garage/customize UI will use, so the
## garage never needs its own bespoke assembly logic.

class AssembledCar:
	var root: Node2D
	var body: CarBody
	var wheels: Array[CarWheel] = []
	var engine: Node2D

## Instances and wires everything under a new root Node2D added to `parent`
## at `spawn_position`. Wheels are matched to the body's WheelMount markers
## in order; extra wheel scenes beyond the body's mount count are ignored.
static func assemble(body_scene: PackedScene, wheel_scenes: Array[PackedScene], engine_scene: PackedScene, parent: Node, spawn_position: Vector2) -> AssembledCar:
	var root := Node2D.new()
	root.name = "Car"
	root.position = spawn_position
	parent.add_child(root)

	var body_instance := body_scene.instantiate() as CarBody
	root.add_child(body_instance)

	var mounts := body_instance.get_wheel_mounts()
	var wheels: Array[CarWheel] = []
	var joints: Array[PinJoint2D] = []
	var wheel_count := mini(wheel_scenes.size(), mounts.size())
	for i in wheel_count:
		var mount := mounts[i]
		var wheel_instance := wheel_scenes[i].instantiate() as CarWheel
		root.add_child(wheel_instance)
		wheel_instance.global_position = mount.global_position
		wheel_instance.chassis = body_instance
		wheels.append(wheel_instance)

		var joint := PinJoint2D.new()
		root.add_child(joint)
		joint.global_position = mount.global_position
		joint.node_a = joint.get_path_to(body_instance)
		joint.node_b = joint.get_path_to(wheel_instance)
		joints.append(joint)

	var engine_instance: Node2D = null
	var engine_power := 0.0
	var engine_data: EnginePartData = null
	if engine_scene != null:
		engine_instance = engine_scene.instantiate()
		body_instance.add_child(engine_instance)
		# Ride on the body's EngineMount so the engine sits where THIS
		# body's art says it goes (hood/top/stern), not on the body origin.
		body_instance.place_engine(engine_instance)
		engine_data = engine_instance.get("part_data")
		if engine_data != null:
			engine_power = engine_data.power

	var autosteer := CarAutosteer.new()
	autosteer.body = body_instance
	body_instance.add_child(autosteer)

	# Engine power IS each wheel's target rotation speed (rad/s) — every
	# wheel's motor tries to hold this same speed, like a solid driven
	# axle. The car's actual ground speed emerges from how well each
	# wheel's shape can grip at that spin rate, not from a separate force.
	for wheel in wheels:
		wheel.target_angular_velocity = engine_power

	RaceCarAudio.register(root)
	var engine_sound_profile := EngineSoundProfile.for_engine(engine_data)
	if engine_sound_profile != null:
		var engine_audio := CarEngineAudio.new()
		engine_audio.profile = engine_sound_profile
		engine_audio.wheels = wheels
		engine_audio.engine_power = engine_power
		body_instance.add_child(engine_audio)

	# Damage/shatter: a wheel breaking detaches just its own joint (the
	# rest of the car keeps going, lopsided). The body breaking detaches
	# every joint — there's nothing left to hold the wheels on, so they
	# carry on rolling riderless.
	for i in wheels.size():
		var wheel: CarWheel = wheels[i]
		var joint: PinJoint2D = joints[i]
		var wheel_damage := CarPartDamage.new()
		wheel_damage.target = wheel
		wheel_damage.part_data = wheel.part_data
		wheel.add_child(wheel_damage)
		wheel_damage.broken.connect(func() -> void:
			if not is_instance_valid(wheel):
				return
			print("BREAK: ", root.name, " lost a ", wheel.part_data.display_name if wheel.part_data else "wheel")
			if is_instance_valid(joint):
				joint.queue_free()
			wheels.erase(wheel)
			PartShatter.shatter(wheel, _get_part_color(wheel), root)
		)

	var body_damage := CarPartDamage.new()
	body_damage.target = body_instance
	body_damage.part_data = body_instance.part_data
	body_instance.add_child(body_damage)
	body_damage.broken.connect(func() -> void:
		if not is_instance_valid(body_instance):
			return
		print("BREAK: ", root.name, " body destroyed!")
		if engine_data != null:
			RaceCarAudio.play(root, &"engine_stall", body_instance.global_position, -4.0)
		for joint in joints:
			if is_instance_valid(joint):
				joint.queue_free()
		PartShatter.shatter(body_instance, _get_part_color(body_instance), root)
	)

	var result := AssembledCar.new()
	result.root = root
	result.body = body_instance
	result.wheels = wheels
	result.engine = engine_instance
	return result

## Same as assemble(), but starting from a saved CarModelData (the format
## Inventory/the garage use) instead of separate body/wheel/engine scenes —
## loads each part's own scene_path and hands off to assemble(). Every race
## setup script that puts the player's own garage car on a track goes
## through this, so there's one place that knows how a CarModelData turns
## into a real rig. Returns null if the car has no body (or the body has
## no scene of its own) rather than assembling something with nothing to
## sit on.
static func assemble_from_car_data(car_data: CarModelData, parent: Node, spawn_position: Vector2) -> AssembledCar:
	if car_data == null or car_data.body == null or car_data.body.scene_path.is_empty():
		return null
	var body_scene: PackedScene = load(car_data.body.scene_path)
	var wheel_scenes: Array[PackedScene] = []
	for wheel in car_data.wheels:
		if wheel != null and not wheel.scene_path.is_empty():
			wheel_scenes.append(load(wheel.scene_path))
	var engine_scene: PackedScene = null
	if car_data.engine != null and not car_data.engine.scene_path.is_empty():
		engine_scene = load(car_data.engine.scene_path)
	return assemble(body_scene, wheel_scenes, engine_scene, parent, spawn_position)

## The part's own art colour, taken off its first Polygon2D. Nested search on
## purpose: the race harness reparents a part's art under a wrapper node, and
## the colour is read again later, when a part shatters.
static func _get_part_color(node: Node) -> Color:
	for child in node.find_children("*", "Polygon2D", true, false):
		if child is Polygon2D:
			return (child as Polygon2D).color
	return Color(0.5, 0.5, 0.5, 1.0)
