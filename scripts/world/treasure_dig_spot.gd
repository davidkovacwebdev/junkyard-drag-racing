class_name TreasureDigSpot
extends Node2D
## Where Gus the smith dug up his one real treasure coin, west of the docks,
## marked on the player's map at the end of "Graveyard Shift": an X on the
## ground and a DIG_SPOT icon on the minimap and the full map. Placed by
## StoryDirector once that quest is done (and by NightDiggerCutscene the
## moment Gus marks it).

const SPOT := Vector2(8350.0, 2330.0)
const PLACE_NAME := "Treasure Area Spot"
## The X scuffed into the dirt: two chunky bars.
const BAR := Vector2(90.0, 14.0)
const DIRT := Color(0.36, 0.27, 0.19, 0.8)

static func place(sortables: Node) -> void:
	if sortables == null or sortables.get_node_or_null(^"TreasureDigSpot") != null:
		return
	var spot := TreasureDigSpot.new()
	spot.name = "TreasureDigSpot"
	spot.position = SPOT
	var marker := MinimapMarker.new()
	marker.kind = MinimapMarker.Kind.DIG_SPOT
	marker.place_name_override = PLACE_NAME
	spot.add_child(marker)
	sortables.add_child(spot)

## Takes it off the map again (that part of the story was rewound).
static func remove(sortables: Node) -> void:
	var spot := sortables.get_node_or_null(^"TreasureDigSpot") if sortables != null else null
	if spot != null:
		spot.queue_free()

func _ready() -> void:
	z_index = -1

func _draw() -> void:
	for angle: float in [0.7, -0.75]:
		draw_set_transform(Vector2.ZERO, angle, Vector2(1.0, 0.55))
		draw_rect(Rect2(-BAR * 0.5, BAR), DIRT)
	draw_set_transform(Vector2.ZERO)
