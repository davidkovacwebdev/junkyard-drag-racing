extends Node
## Part registry (autoload singleton "PartDatabase"). Loads every body/
## wheel/engine scene under scenes/parts/ once at boot and keeps just
## their PartData — the garage's part browser reads from here, not from
## any specific car's installed parts.

var bodies: Array[BodyPartData] = []
var wheels: Array[WheelPartData] = []
var engines: Array[EnginePartData] = []

const _BODY_SCENES := [
	"res://scenes/parts/bodies/body_wrecked_car.tscn",
	"res://scenes/parts/bodies/body_fridge.tscn",
	"res://scenes/parts/bodies/body_plank.tscn",
	"res://scenes/parts/bodies/body_boat.tscn",
	"res://scenes/parts/bodies/body_sofa.tscn",
]
const _WHEEL_SCENES := [
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
		bodies.append(_extract_part_data(path) as BodyPartData)
	for path in _WHEEL_SCENES:
		wheels.append(_extract_part_data(path) as WheelPartData)
	for path in _ENGINE_SCENES:
		engines.append(_extract_part_data(path) as EnginePartData)

## Each part scene is a full physics rig (RigidBody2D + shape/visual) with
## its PartData as one exported sub-resource — instantiate just long
## enough to pull that resource back out, since it's the only part of the
## scene the garage browser actually needs.
func _extract_part_data(scene_path: String) -> PartData:
	var instance := (load(scene_path) as PackedScene).instantiate()
	var data: PartData = instance.part_data
	data.scene_path = scene_path
	instance.free()
	return data
