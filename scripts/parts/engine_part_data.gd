class_name EnginePartData
extends PartData

## Target wheel rotation speed (rad/s) this engine drives every wheel to.
@export var power: float = 3.5
## False for engines that are sold somewhere (the farm's horse) rather than
## dug out of bins and junk heaps.
@export var found_in_junk: bool = true
## SoundLibrary sound played when the car first starts up on the map.
@export var start_sound: StringName = &"ignition_click"
## SoundLibrary sound played when the player kicks in the sprint.
@export var boost_sound: StringName = &"backfire"

func _init() -> void:
	category = Category.ENGINE
