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
]
const _WHEEL_SCENES := [
	"res://scenes/parts/wheels/wheel_standard.tscn",
	"res://scenes/parts/wheels/wheel_bicycle.tscn",
	"res://scenes/parts/wheels/wheel_square.tscn",
	"res://scenes/parts/wheels/wheel_triangle.tscn",
	"res://scenes/parts/wheels/wheel_tv.tscn",
	"res://scenes/parts/wheels/wheel_toilet.tscn",
	"res://scenes/parts/wheels/wheel_paddle.tscn",
]
const _ENGINE_SCENES := [
	"res://scenes/parts/engines/engine_v6.tscn",
	"res://scenes/parts/engines/engine_jet.tscn",
	"res://scenes/parts/engines/engine_sail.tscn",
	"res://scenes/parts/engines/engine_propeller.tscn",
	"res://scenes/parts/engines/engine_boiler.tscn",
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
## in any non-empty category always lands in tier 1, which is what makes
## Inventory._worst() below safe to just look for tier == 1.
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
