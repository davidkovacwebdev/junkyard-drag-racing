@tool
class_name TreePartData
extends Resource
## Cosmetic data shared by every tree part (trunk, canopy, decoration).
## Mirrors BuildingPartData: the actual shape lives in the part's own scene
## as Polygon2D children, this resource just describes it.
##
## @tool so the Tree Creator dock can instantiate part scenes and read
## their data while the editor is running (see tree_data.gd).
##
## Parts are authored in "tree space": origin at the ground, +y pointing
## down, so a trunk spans roughly y=0 (ground) up to y=-170 (canopy line)
## and every part can be dropped into the tree root with no anchor math at
## all, same as building parts. Canopies are drawn around y=-210 and
## decorations hang off the trunk or sit at its base.

enum Slot { TRUNK, CANOPY, DECORATION }

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.TRUNK

## Nudges this part up/down the draw order relative to its slot's default
## (negative = further back). Used, for example, by a decoration that
## should sit behind the trunk instead of in front of it.
@export var z_offset: int = 0

static func slot_name(slot: Slot) -> String:
	return Slot.keys()[slot].capitalize()
