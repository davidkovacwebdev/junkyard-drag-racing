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
}

@export var kind: Kind = Kind.HOME

func _ready() -> void:
	add_to_group(GROUP)

## The name quests use for the place this marker sits on (a quest's
## `objective_place`): the landmark's own `display_name`, or, for a landmark
## that keeps it on a child (the junkyard's Entrance), that child's.
func place_name() -> String:
	var place := get_parent()
	if place == null:
		return ""
	if place.get("display_name") != null:
		return String(place.get("display_name"))
	for child in place.get_children():
		if child != self and child.get("display_name") != null:
			return String(child.get("display_name"))
	return ""
