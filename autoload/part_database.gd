extends Node
## Part registry (autoload singleton "PartDatabase"). Loads every body/
## wheel/engine scene under scenes/parts/ once at boot and keeps just
## their PartData — the garage's part browser reads from here, not from
## any specific car's installed parts.

var bodies: Array[BodyPartData] = []
var wheels: Array[WheelPartData] = []
var engines: Array[EnginePartData] = []

const _BODY_SCENES := [
	"res://scenes/parts/bodies/body_classic.tscn",
	"res://scenes/parts/bodies/body_wrecked_car.tscn",
	"res://scenes/parts/bodies/body_fridge.tscn",
	"res://scenes/parts/bodies/body_plank.tscn",
	"res://scenes/parts/bodies/body_boat.tscn",
	"res://scenes/parts/bodies/body_sofa.tscn",
	"res://scenes/parts/bodies/body_pipes.tscn",
	"res://scenes/parts/bodies/body_bathtub.tscn",
	"res://scenes/parts/bodies/body_mattress.tscn",
	"res://scenes/parts/bodies/body_limo.tscn",
	"res://scenes/parts/bodies/body_radiator.tscn",
	"res://scenes/parts/bodies/body_bicycle.tscn",
]
const _WHEEL_SCENES := [
	"res://scenes/parts/wheels/wheel_standard.tscn",
	"res://scenes/parts/wheels/wheel_bicycle.tscn",
	"res://scenes/parts/wheels/wheel_square.tscn",
	"res://scenes/parts/wheels/wheel_triangle.tscn",
	"res://scenes/parts/wheels/wheel_tv.tscn",
	"res://scenes/parts/wheels/wheel_toilet.tscn",
	"res://scenes/parts/wheels/wheel_paddle.tscn",
	"res://scenes/parts/wheels/wheel_saw_blade.tscn",
	"res://scenes/parts/wheels/wheel_trash_lid.tscn",
	"res://scenes/parts/wheels/wheel_satellite_dish.tscn",
	"res://scenes/parts/wheels/wheel_tractor_seat.tscn",
	"res://scenes/parts/wheels/wheel_alarm_clock.tscn",
	"res://scenes/parts/wheels/wheel_pizza_tray.tscn",
	"res://scenes/parts/wheels/wheel_office_chair.tscn",
	"res://scenes/parts/wheels/wheel_traffic_cone.tscn",
	"res://scenes/parts/wheels/wheel_frying_pan.tscn",
	"res://scenes/parts/wheels/wheel_washer_door.tscn",
	"res://scenes/parts/wheels/wheel_shopping_cart.tscn",
	"res://scenes/parts/wheels/wheel_metal_bucket.tscn",
	"res://scenes/parts/wheels/wheel_bbq_grill.tscn",
	"res://scenes/parts/wheels/wheel_stop_sign.tscn",
	"res://scenes/parts/wheels/wheel_ceiling_fan.tscn",
	"res://scenes/parts/wheels/wheel_wood_barrel.tscn",
	"res://scenes/parts/wheels/wheel_metal_barrel.tscn",
	"res://scenes/parts/wheels/wheel_dartboard.tscn",
	"res://scenes/parts/wheels/wheel_pogo.tscn",
	"res://scenes/parts/wheels/wheel_prosthetic_leg.tscn",
	"res://scenes/parts/wheels/wheel_tractor.tscn",
	"res://scenes/parts/wheels/wheel_hamster.tscn",
]
const _ENGINE_SCENES := [
	"res://scenes/parts/engines/engine_v6.tscn",
	"res://scenes/parts/engines/engine_jet.tscn",
	"res://scenes/parts/engines/engine_sail.tscn",
	"res://scenes/parts/engines/engine_propeller.tscn",
	"res://scenes/parts/engines/engine_boiler.tscn",
	"res://scenes/parts/engines/engine_soda_bottle.tscn",
	"res://scenes/parts/engines/engine_blowtorch.tscn",
	"res://scenes/parts/engines/engine_hair_dryer.tscn",
	"res://scenes/parts/engines/engine_leaf_blower.tscn",
	"res://scenes/parts/engines/engine_vacuum_cleaner.tscn",
	"res://scenes/parts/engines/engine_chainsaw.tscn",
	"res://scenes/parts/engines/engine_lawn_mower.tscn",
	"res://scenes/parts/engines/engine_washing_machine_motor.tscn",
	"res://scenes/parts/engines/engine_electric_drill.tscn",
	"res://scenes/parts/engines/engine_angle_grinder.tscn",
	"res://scenes/parts/engines/engine_industrial_fan.tscn",
	"res://scenes/parts/engines/engine_air_compressor.tscn",
	"res://scenes/parts/engines/engine_pressure_washer.tscn",
	"res://scenes/parts/engines/engine_shop_vacuum.tscn",
	"res://scenes/parts/engines/engine_blender.tscn",
	"res://scenes/parts/engines/engine_food_processor.tscn",
	"res://scenes/parts/engines/engine_sewing_machine.tscn",
	"res://scenes/parts/engines/engine_treadmill_motor.tscn",
	"res://scenes/parts/engines/engine_ceiling_fan_motor.tscn",
	"res://scenes/parts/engines/engine_rc_car_motor.tscn",
	"res://scenes/parts/engines/engine_electric_scooter_motor.tscn",
	"res://scenes/parts/engines/engine_toy_car_motor.tscn",
	"res://scenes/parts/engines/engine_generator.tscn",
	"res://scenes/parts/engines/engine_outboard_motor.tscn",
	"res://scenes/parts/engines/engine_go_kart.tscn",
	"res://scenes/parts/engines/engine_chainsaw_motor.tscn",
	"res://scenes/parts/engines/engine_industrial_mixer.tscn",
	"res://scenes/parts/engines/engine_meat_grinder.tscn",
	"res://scenes/parts/engines/engine_paint_sprayer.tscn",
	"res://scenes/parts/engines/engine_pneumatic_jack.tscn",
	"res://scenes/parts/engines/engine_air_horn.tscn",
	"res://scenes/parts/engines/engine_fire_extinguisher.tscn",
	"res://scenes/parts/engines/engine_soda_keg.tscn",
	"res://scenes/parts/engines/engine_co2_tank.tscn",
	"res://scenes/parts/engines/engine_air_tank.tscn",
	"res://scenes/parts/engines/engine_firework_rocket.tscn",
]

func _ready() -> void:
	for path in _BODY_SCENES:
		bodies.append(load_part_data(path) as BodyPartData)
	for path in _WHEEL_SCENES:
		wheels.append(load_part_data(path) as WheelPartData)
	for path in _ENGINE_SCENES:
		engines.append(load_part_data(path) as EnginePartData)
	_assign_tiers(bodies)
	_assign_tiers(wheels)
	_assign_tiers(engines)

## Ranks a category's parts by performance_score() and splits them into
## PartData.TIER_COUNT roughly-even groups — a tier is a quartile within
## its OWN category (comparing a wheel's mass to an engine's would be
## meaningless), so "how good is this part" always means "compared to the
## other parts you could put in the same slot". The lowest-scoring part
## in any non-empty category always lands in tier 1.
static func _assign_tiers(parts: Array) -> void:
	if parts.is_empty():
		return
	var ranked := parts.duplicate()
	ranked.sort_custom(func(a: PartData, b: PartData) -> bool:
		return a.performance_score() < b.performance_score()
	)
	for i in ranked.size():
		var part: PartData = ranked[i]
		part.tier = clampi(1 + (i * PartData.TIER_COUNT) / ranked.size(), 1, PartData.TIER_COUNT)

## Instances a part scene just long enough to pull its PartData back out,
## tagging it with the scene it came from. The catalog and car-building
## code both need that scene_path so they can instantiate the real part.
static func load_part_data(scene_path: String) -> PartData:
	var instance: Node = (load(scene_path) as PackedScene).instantiate()
	var data: PartData = instance.get("part_data") as PartData
	data.scene_path = scene_path
	instance.free()
	return data

## How many wheel mounts the body's scene actually declares (its
## "WheelMount*" Marker2D children), used to keep a CarModelData's wheels
## array sized to whatever body is currently equipped.
static func wheel_mount_count(body: BodyPartData) -> int:
	if body == null or body.scene_path.is_empty():
		return 0
	var instance: Node = (load(body.scene_path) as PackedScene).instantiate()
	var body_instance := instance as CarBody
	var count := 0
	if body_instance != null:
		count = body_instance.get_wheel_mounts().size()
	instance.free()
	return count
