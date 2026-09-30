@tool
class_name CharacterPartData
extends Resource
## Cosmetic data shared by every character part (torso, head, hair, ...).
## Mirrors PartData on the car side: the actual shape lives in the part's
## own scene as Polygon2D children, this resource just describes it.
##
## @tool so the Character Creator dock can instantiate part scenes and
## read their data while the editor is running (see character_data.gd).
##
## Parts are authored in "character space": origin at the ground between
## the feet, +y pointing down. So a torso polygon spans roughly y=-172..
## -96, a head y=-240..-176, etc. That means every part can simply be
## dropped into the character root with no anchor math at all.

enum Slot { LEGS, BOOTS, TORSO, HEAD, HAIR, EYES, ACCESSORY }

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.TORSO

## Nudges this part up/down the draw order relative to its slot's default
## (negative = further back). Used, for example, by a backpack to ride
## behind the torso even though ACCESSORY normally draws last.
@export var z_offset: int = 0

## Parts made for one specific NPC (Grandpa's wheelchair, beard, ...). The
## editor dock still offers them; the player's own character creation hides
## them so nobody can dress up as a named character.
@export var npc_only: bool = false

static func slot_name(slot: Slot) -> String:
	return Slot.keys()[slot].capitalize()
