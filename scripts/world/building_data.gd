@tool
class_name BuildingData
extends Resource
## A saved building loadout: one optional part scene per slot. This is
## the thing the Building Creator dock writes to res://buildings/*.tres,
## and it's what BuildingAssembler / ComposedBuilding read back at runtime.
##
## @tool is required, not cosmetic: the editor dock creates and loads these
## resources while the editor is running, and a non-tool script comes back
## as a placeholder instance in that context — see CharacterData for the
## full explanation of why that breaks get_part()/set_part().
##
## Storing PackedScene references (rather than ids that need a lookup) is
## deliberate, same as CharacterData: the resource is self-contained, so
## loading a building is just ResourceLoader.load(), with no database to
## keep in sync.

@export var display_name: String = "New Building"

@export var wall_scene: PackedScene
@export var roof_scene: PackedScene
@export var door_scene: PackedScene
@export var window_scene: PackedScene
@export var decoration_scene: PackedScene

## How much of the footprint's height is solid collision, hugging the
## ground — same idea as Obstacle.collision_height_fraction, just carried
## on the building's own data instead of tuned per placed instance.
@export_range(0.0, 1.0) var collision_height_fraction: float = 0.35
@export_range(0.0, 100.0) var corner_radius: float = 20.0

func get_part(slot: BuildingPartData.Slot) -> PackedScene:
	match slot:
		BuildingPartData.Slot.WALL:
			return wall_scene
		BuildingPartData.Slot.ROOF:
			return roof_scene
		BuildingPartData.Slot.DOOR:
			return door_scene
		BuildingPartData.Slot.WINDOW:
			return window_scene
		BuildingPartData.Slot.DECORATION:
			return decoration_scene
	return null

func set_part(slot: BuildingPartData.Slot, scene: PackedScene) -> void:
	match slot:
		BuildingPartData.Slot.WALL:
			wall_scene = scene
		BuildingPartData.Slot.ROOF:
			roof_scene = scene
		BuildingPartData.Slot.DOOR:
			door_scene = scene
		BuildingPartData.Slot.WINDOW:
			window_scene = scene
		BuildingPartData.Slot.DECORATION:
			decoration_scene = scene
