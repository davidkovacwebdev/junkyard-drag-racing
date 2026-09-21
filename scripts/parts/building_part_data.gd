@tool
class_name BuildingPartData
extends Resource
## Cosmetic data shared by every building part (wall, roof, door, window,
## decoration). Mirrors CharacterPartData: the actual shape lives in the
## part's own scene as Polygon2D children, this resource just describes it.
##
## @tool so the Building Creator dock can instantiate part scenes and read
## their data while the editor is running (see building_data.gd).
##
## Parts are authored in "building space": origin at the ground, +y
## pointing down, so a wall spans roughly y=0 (ground) up to y=-180
## (roof line). That way every part can be dropped into the building root
## with no anchor math at all, same as character parts.

enum Slot { WALL, ROOF, DOOR, WINDOW, DECORATION }

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.WALL

## Nudges this part up/down the draw order relative to its slot's default
## (negative = further back). Used, for example, by a decoration that
## should sit behind the wall instead of in front of it.
@export var z_offset: int = 0

static func slot_name(slot: Slot) -> String:
	return Slot.keys()[slot].capitalize()
