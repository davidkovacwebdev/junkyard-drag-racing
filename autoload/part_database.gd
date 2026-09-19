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
]
const _WHEEL_SCENES := [
	"res://scenes/parts/wheels/wheel_standard.tscn",
	"res://scenes/parts/wheels/wheel_bicycle.tscn",
	"res://scenes/parts/wheels/wheel_square.tscn",
	"res://scenes/parts/wheels/wheel_triangle.tscn",
	"res://scenes/parts/wheels/wheel_tv.tscn",
	"res://scenes/parts/wheels/wheel_toilet.tscn",
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
