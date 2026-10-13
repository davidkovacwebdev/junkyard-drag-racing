class_name TreasureMark
extends Node2D
## Grandpa's prosthetic leg, stuck upside down in the dirt where the metal
## detector went wild ("Beep Beep"): the exact spot the treasure's buried,
## to come back and dig (MarkSpotCutscene sticks it in). The same colours as
## the leg part (wheel_prosthetic_leg.tscn): the socket half buried, the
## steel pylon up, the sneaker on top. Placed by TreasureStory once the spot
## is marked, and again every time the map loads after, until it's dug up.

const SOCKET := Color(0.85, 0.68, 0.55, 1)
const PYLON := Color(0.62, 0.63, 0.66, 1)
const SNEAKER := Color(0.36, 0.45, 0.6, 1)
const SOLE := Color(0.9, 0.88, 0.82, 1)
const HEIGHT := 64.0

static func place(sortables: Node, spot: Vector2) -> void:
	if sortables == null or sortables.get_node_or_null(^"TreasureMark") != null:
		return
	var mark := TreasureMark.new()
	mark.name = "TreasureMark"
	mark.position = spot
	sortables.add_child(mark)

static func remove(sortables: Node) -> void:
	var mark := sortables.get_node_or_null(^"TreasureMark") if sortables != null else null
	if mark != null:
		mark.queue_free()

func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 18.0, 6.0), UiPalette.SHADOW)
	# The socket, half in the ground.
	draw_colored_polygon(PackedVector2Array([Vector2(-11.0, 2.0), Vector2(11.0, 2.0),
			Vector2(8.0, -14.0), Vector2(-8.0, -14.0)]), SOCKET)
	draw_colored_polygon(FlatProps.sliver(Vector2(0.0, -12.0), Vector2(2.0, -HEIGHT + 10.0), 7.0), PYLON)
	# The sneaker, toe pointing up and over, sole to the sky.
	var ankle := Vector2(2.0, -HEIGHT + 10.0)
	draw_colored_polygon(PackedVector2Array([ankle + Vector2(-8.0, 4.0), ankle + Vector2(8.0, 4.0),
			ankle + Vector2(26.0, -4.0), ankle + Vector2(24.0, -12.0), ankle + Vector2(-8.0, -12.0)]), SNEAKER)
	draw_colored_polygon(PackedVector2Array([ankle + Vector2(-9.0, -12.0), ankle + Vector2(25.0, -12.0),
			ankle + Vector2(24.0, -18.0), ankle + Vector2(-9.0, -18.0)]), SOLE)
