class_name CarAssembler
extends RefCounted
## Builds a physics-driven car at runtime from a body scene, an array of
## wheel scenes, and an engine scene. This is the one code path both the
## Phase 1 test rigs and the later garage/customize UI will use, so the
## garage never needs its own bespoke assembly logic.

## Damping on wheels left rolling after the body breaks. Round ones would
## otherwise roll forever: the physics has no rolling resistance.
const LOOSE_WHEEL_DAMP := 1.5
## Each wheel motor's stall torque per point of engine power.
const STALL_TORQUE_PER_POWER := 300000.0
## Global buff on every engine's power, so all cars get faster together.
const ENGINE_POWER_MULTIPLIER := 1.5625
## Gap left under a car's lowest point at spawn: enough to not start inside
## the ground, small enough that it settles instead of dropping.
const SPAWN_GAP := 1.0

class AssembledCar:
	var root: Node2D
	var body: CarBody
	var wheels: Array[CarWheel] = []
	var engine: Node2D

## Instances and wires everything under a new root Node2D added to `parent`.
## The body origin goes at `spawn_position.x`, and `spawn_position.y` is the
## ground the car stands on. Wheels are matched to the body's WheelMount markers
## in order; extra wheel scenes beyond the body's mount count are ignored.
static func assemble(body_scene: PackedScene, wheel_scenes: Array[PackedScene], engine_scene: PackedScene, parent: Node, spawn_position: Vector2) -> AssembledCar:
	var wheel_instances: Array[CarWheel] = []
	for scene in wheel_scenes:
		wheel_instances.append(scene.instantiate() as CarWheel)
	var engine_instance: Node2D = engine_scene.instantiate() if engine_scene != null else null
	return assemble_parts(body_scene.instantiate() as CarBody, wheel_instances, engine_instance, parent, spawn_position)

## assemble() for parts that are already instanced (see PartFactory), which is
## how a forged part gets onto a track with its mashed art and its own stats.
## Takes ownership of every instance passed in; wheels beyond the body's mount
## count are freed.
static func assemble_parts(body_instance: CarBody, wheel_instances: Array[CarWheel], engine_instance: Node2D, parent: Node, spawn_position: Vector2) -> AssembledCar:
	var root := Node2D.new()
	root.name = "Car"
	root.position = spawn_position
	parent.add_child(root)

	root.add_child(body_instance)

	var mounts := body_instance.get_wheel_mounts()
	var wheels: Array[CarWheel] = []
	var joints: Array[Joint2D] = []
	var joints_by_wheel: Array[Array] = []
	var wheel_count := mini(wheel_instances.size(), mounts.size())
	for i in range(wheel_count, wheel_instances.size()):
		wheel_instances[i].free()
	for i in wheel_count:
		var mount := mounts[i]
		var wheel_instance := wheel_instances[i]
		root.add_child(wheel_instance)
		wheel_instance.global_position = mount.global_position
		wheel_instance.chassis = body_instance
		wheels.append(wheel_instance)

	# Placed by its lowest point, not its body origin:
	# wheels hang below the body by different amounts, and a wheel spawned
	# inside the road gets blasted out by the solver hard enough to break parts.
	root.position.y += spawn_position.y - SPAWN_GAP - _lowest_collision_y(root)

	# Hung only after the move: a joint keeps the anchor it was made with and
	# yanks its wheel back there on the first step.
	for i in wheel_count:
		var wheel_joints := _suspend_wheel(body_instance, wheels[i], mounts[i].global_position, wheel_count, root)
		joints_by_wheel.append(wheel_joints)
		joints.append_array(wheel_joints)

	# Neighbouring wheels on a short body can overlap; left colliding they
	# grind against each other and jam the car.
	for i in wheels.size():
		for j in range(i + 1, wheels.size()):
			wheels[i].add_collision_exception_with(wheels[j])

	var engine_power := 0.0
	var engine_data: EnginePartData = null
	if engine_instance != null:
		body_instance.add_child(engine_instance)
		# Ride on the body's EngineMount so the engine sits where THIS
		# body's art says it goes (hood/top/stern), not on the body origin.
		body_instance.place_engine(engine_instance)
		engine_data = engine_instance.get("part_data")
		if engine_data != null:
			engine_power = engine_data.power * ENGINE_POWER_MULTIPLIER

	var autosteer := CarAutosteer.new()
	autosteer.body = body_instance
	body_instance.add_child(autosteer)

	# Engine power is each wheel's top spin speed (rad/s) and scales its
	# torque. The car's ground speed comes only from how well each wheel's
	# shape grips the ground under that torque.
	for wheel in wheels:
		wheel.target_angular_velocity = engine_power
		wheel.stall_torque = engine_power * STALL_TORQUE_PER_POWER

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
	var suspension_wheel_protection: float = body_instance.part_data.suspension_wheel_protection if body_instance.part_data != null else 0.0
	for i in wheels.size():
		var wheel: CarWheel = wheels[i]
		var wheel_joints: Array = joints_by_wheel[i]
		var wheel_damage := CarPartDamage.new()
		wheel_damage.target = wheel
		wheel_damage.part_data = wheel.part_data
		wheel_damage.absorption = wheel.part_data.absorption if wheel.part_data != null else 0.0
		wheel_damage.ground_absorption = suspension_wheel_protection
		wheel.contact_monitor = true
		wheel.max_contacts_reported = 4
		wheel.add_child(wheel_damage)
		wheel_damage.broken.connect(func() -> void:
			if not is_instance_valid(wheel):
				return
			print("BREAK: ", root.name, " lost a ", wheel.part_data.display_name if wheel.part_data else "wheel")
			for joint in wheel_joints:
				if is_instance_valid(joint):
					joint.queue_free()
			wheels.erase(wheel)
			PartShatter.shatter(wheel, _get_part_color(wheel), root)
		)

	var body_damage := CarPartDamage.new()
	body_damage.target = body_instance
	body_damage.part_data = body_instance.part_data
	body_damage.absorption = _average_absorption(wheels)
	body_damage.ground_absorption = suspension_wheel_protection
	body_damage.linked_contact_parts = wheels
	body_instance.contact_monitor = true
	body_instance.max_contacts_reported = 4
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
		# No engine left to drive them: loose wheels roll on and wind down.
		for wheel in wheels:
			if is_instance_valid(wheel):
				wheel.target_angular_velocity = 0.0
				wheel.angular_damp = LOOSE_WHEEL_DAMP
				wheel.linear_damp = LOOSE_WHEEL_DAMP
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
## instances each part through PartFactory and hands off to assemble_parts(). Every race
## setup script that puts the player's own garage car on a track goes
## through this, so there's one place that knows how a CarModelData turns
## into a real rig. Returns null if the car has no body (or the body has
## no scene of its own) rather than assembling something with nothing to
## sit on.
static func assemble_from_car_data(car_data: CarModelData, parent: Node, spawn_position: Vector2) -> AssembledCar:
	if car_data == null or car_data.body == null or car_data.body.scene_path.is_empty():
		return null
	var wheel_instances: Array[CarWheel] = []
	for wheel in car_data.wheels:
		if wheel != null and not wheel.scene_path.is_empty():
			wheel_instances.append(PartFactory.instantiate(wheel) as CarWheel)
	return assemble_parts(PartFactory.instantiate(car_data.body) as CarBody, wheel_instances,
			PartFactory.instantiate(car_data.engine), parent, spawn_position)

## Hangs `wheel` off the body on a sprung, damped slide along the body's own
## up/down axis: a groove keeps the axle in line under its mount, and a spring
## holds the body up. The body's BodyPartData sets how soft it is. Spring
## rates are worked out from the body's weight, so the same settings feel the
## same on a light mattress and a heavy radiator.
static func _suspend_wheel(body: CarBody, wheel: CarWheel, mount: Vector2, wheel_count: int, root: Node2D) -> Array[Joint2D]:
	var data := body.part_data
	var sag: float = data.suspension_sag if data != null else 6.0
	var travel: float = data.suspension_travel if data != null else 14.0
	var damping_ratio: float = data.suspension_damping_ratio if data != null else 0.7
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var weight_on_wheel := body.mass * gravity * body.gravity_scale / wheel_count
	var stiffness := weight_on_wheel / maxf(sag, 0.5)
	var sprung_mass := body.mass / wheel_count * wheel.mass / (body.mass / wheel_count + wheel.mass)

	var top := mount - body.global_transform.y.normalized() * travel

	var groove := GrooveJoint2D.new()
	root.add_child(groove)
	groove.global_position = top
	groove.global_rotation = body.global_rotation
	groove.length = travel * 2.0
	groove.initial_offset = travel
	groove.node_a = groove.get_path_to(body)
	groove.node_b = groove.get_path_to(wheel)

	var spring := DampedSpringJoint2D.new()
	root.add_child(spring)
	spring.global_position = top
	spring.global_rotation = body.global_rotation
	spring.length = travel
	spring.rest_length = travel + sag
	spring.stiffness = stiffness
	spring.damping = damping_ratio * 2.0 * sqrt(stiffness * sprung_mass)
	spring.node_a = spring.get_path_to(body)
	spring.node_b = spring.get_path_to(wheel)
	return [groove, spring]

## The part's own art colour, taken off its first Polygon2D. Nested search on
## purpose: the race harness reparents a part's art under a wrapper node, and
## the colour is read again later, when a part shatters.
static func _get_part_color(node: Node) -> Color:
	for child in node.find_children("*", "Polygon2D", true, false):
		if child is Polygon2D:
			return (child as Polygon2D).color
	return Color(0.5, 0.5, 0.5, 1.0)

static func _lowest_collision_y(car_root: Node2D) -> float:
	var lowest := -INF
	for collider in car_root.find_children("*", "CollisionPolygon2D", true, false):
		var polygon_node := collider as CollisionPolygon2D
		for point in polygon_node.polygon:
			lowest = maxf(lowest, (polygon_node.global_transform * point).y)
	for collider in car_root.find_children("*", "CollisionShape2D", true, false):
		var shape_node := collider as CollisionShape2D
		if shape_node.shape != null:
			var bounds := shape_node.global_transform * shape_node.shape.get_rect()
			lowest = maxf(lowest, bounds.end.y)
	return lowest if lowest > -INF else car_root.global_position.y

static func _average_absorption(wheels: Array[CarWheel]) -> float:
	var total := 0.0
	for wheel in wheels:
		if wheel.part_data != null:
			total += wheel.part_data.absorption
	return total / maxf(wheels.size(), 1.0)
