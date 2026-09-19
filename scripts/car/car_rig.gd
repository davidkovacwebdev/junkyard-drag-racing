class_name CarRig
extends Node2D
## Thin wrapper: assembles a car from a chosen loadout (body/wheels/engine
## scenes) as soon as it enters the tree, so a race scene can just place a
## CarRig node instead of hand-wiring PinJoint2Ds per car in the editor.
## This is the same CarAssembler path the later garage UI will drive.

@export var body_scene: PackedScene
@export var wheel_scenes: Array[PackedScene] = []
@export var engine_scene: PackedScene

var assembled: CarAssembler.AssembledCar

func _ready() -> void:
	assembled = CarAssembler.assemble(body_scene, wheel_scenes, engine_scene, self, Vector2.ZERO)
