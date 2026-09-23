@tool
class_name TreeData
extends Resource
## A saved tree loadout: one optional part scene per slot. This is the thing
## the Tree Creator dock writes to res://trees/*.tres, and it's what
## TreeAssembler / ComposedTree read back at runtime.
##
## @tool is required, not cosmetic: the editor dock creates and loads these
## resources while the editor is running, and a non-tool script comes back as
## a placeholder instance in that context — see BuildingData for the full
## explanation of why that breaks get_part()/set_part().
##
## Storing PackedScene references (rather than ids that need a lookup) is
## deliberate, same as BuildingData: the resource is self-contained, so
## loading a tree is just ResourceLoader.load(), with no database to keep in
## sync.

@export var display_name: String = "New Tree"

@export var trunk_scene: PackedScene
@export var canopy_scene: PackedScene
@export var decoration_scene: PackedScene

## How much of the trunk footprint's height is solid collision, hugging the
## ground. 1.0 (the default) makes the whole trunk solid, which is what a
## tree wants: the car bumps the trunk but drives under the canopy. Same
## idea as BuildingData.collision_height_fraction, just with a different
## sensible default.
@export_range(0.0, 1.0) var collision_height_fraction: float = 1.0
@export_range(0.0, 100.0) var corner_radius: float = 15.0

func get_part(slot: TreePartData.Slot) -> PackedScene:
	match slot:
		TreePartData.Slot.TRUNK:
			return trunk_scene
		TreePartData.Slot.CANOPY:
			return canopy_scene
		TreePartData.Slot.DECORATION:
			return decoration_scene
	return null

func set_part(slot: TreePartData.Slot, scene: PackedScene) -> void:
	match slot:
		TreePartData.Slot.TRUNK:
			trunk_scene = scene
		TreePartData.Slot.CANOPY:
			canopy_scene = scene
		TreePartData.Slot.DECORATION:
			decoration_scene = scene
