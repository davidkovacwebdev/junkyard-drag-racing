class_name MinimapMarker
extends Node2D
## Drop one under a landmark to put it on the overworld Minimap. The icon is
## picked by `kind`; HOME is pinned to the map's edge when it's out of range.

const GROUP := &"minimap_marker"

enum Kind {
	HOME,
	DRAG_STRIP,
	JUNKYARD,
	RAMP,
	FARM,
	FORGE,
	SHOP,
	RALLY,
	HILL_CLIMB,
	DERBY,
	GRAVEYARD,
	GARBAGE_TRUCK,
	HOSPITAL,
	BRIDGE,
}

@export var kind: Kind = Kind.HOME
## The name quests use for this place, for one that has no `display_name`
## to carry it (the garbage truck: a `display_name` would make the car offer
## to talk to it). Empty: the landmark's own, see `place_name()`.
@export var place_name_override: String = ""

func _ready() -> void:
	add_to_group(GROUP)
	# A venue whose booth stands off to one side (the drag strip, say) is
	# marked where the player actually drives up to talk, not mid-track.
	var entrance := _named_node()
	if entrance != get_parent() and entrance is Node2D:
		global_position = (entrance as Node2D).global_position

## The name quests use for the place this marker sits on (a quest's
## `objective_place`): the landmark's own `display_name`, or, for a landmark
## that keeps it on a child (a venue's Entrance booth), that child's.
func place_name() -> String:
	if not place_name_override.is_empty():
		return place_name_override
	var named := _named_node()
	return String(named.get("display_name")) if named != null else ""

## The node carrying the place's `display_name`: the landmark itself, or its
## first child that has one. Null if neither does.
func _named_node() -> Node:
	var place := get_parent()
	if place == null:
		return null
	if place.get("display_name") != null:
		return place
	for child in place.get_children():
		if child != self and child.get("display_name") != null:
			return child
	return null
