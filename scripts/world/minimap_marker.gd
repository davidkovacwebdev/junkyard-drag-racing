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
}

@export var kind: Kind = Kind.HOME

func _ready() -> void:
	add_to_group(GROUP)
