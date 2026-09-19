class_name EnginePartData
extends PartData

## Target wheel rotation speed (rad/s) this engine drives every wheel to.
@export var power: float = 3.5

func _init() -> void:
	category = Category.ENGINE
