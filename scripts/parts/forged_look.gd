class_name ForgedLook
extends Resource
## What the scrap forge did to a part's art, stored as final polygons rather
## than as a recipe, so a forged part always looks the same even if the parts
## it was made from change later. Applied on top of the base part's own scene
## by PartFactory.instantiate(), which keeps the base's script, animation,
## mounts and physics working: only polygons are changed or added.

const FRONT_LAYER := &"ForgeScrapFront"
const BACK_LAYER := &"ForgeScrapBack"

## The catalog part at the bottom of the mash (see PartData.catalog_id()).
@export var base_part_id: StringName
@export var base_display_name: String = ""
## The node in the base scene the grafted scrap rides on (the horse's torso,
## so the junk bolted to it trots along), relative to the part's root.
@export var anchor_path: NodePath = ^"."
## Base Polygon2Ds reshaped or recoloured by the mash, by path from the root.
@export var override_paths: PackedStringArray = PackedStringArray()
@export var override_polygons: Array[PackedVector2Array] = []
@export var override_colors: PackedColorArray = PackedColorArray()
## Grafted scrap in the anchor's space, drawn over and under the base art.
@export var front_polygons: Array[PackedVector2Array] = []
@export var front_colors: PackedColorArray = PackedColorArray()
@export var back_polygons: Array[PackedVector2Array] = []
@export var back_colors: PackedColorArray = PackedColorArray()
## Mount markers (wheel/engine mounts, the horse's lead point) moved to
## follow the bent art, by path from the root.
@export var marker_paths: PackedStringArray = PackedStringArray()
@export var marker_positions: PackedVector2Array = PackedVector2Array()
## Replaces the root's CollisionPolygon2D when set (a mashed wheel rolls on
## its new silhouette).
@export var collision_polygon: PackedVector2Array = PackedVector2Array()

func apply_to(instance: Node) -> void:
	for i in override_paths.size():
		var polygon := instance.get_node_or_null(NodePath(override_paths[i])) as Polygon2D
		if polygon != null:
			polygon.polygon = override_polygons[i]
			polygon.color = override_colors[i]
	for i in marker_paths.size():
		var marker := instance.get_node_or_null(NodePath(marker_paths[i])) as Node2D
		if marker != null:
			marker.position = marker_positions[i]
	var anchor := instance.get_node_or_null(anchor_path)
	if anchor == null:
		anchor = instance
	var back := _build_layer(BACK_LAYER, back_polygons, back_colors)
	anchor.add_child(back)
	anchor.move_child(back, 0)
	anchor.add_child(_build_layer(FRONT_LAYER, front_polygons, front_colors))
	if not collision_polygon.is_empty():
		for child in instance.get_children():
			if child is CollisionPolygon2D:
				(child as CollisionPolygon2D).polygon = collision_polygon
				break

static func is_scrap_layer(node: Node) -> bool:
	return node.name == FRONT_LAYER or node.name == BACK_LAYER

static func _build_layer(layer_name: StringName, polygons: Array[PackedVector2Array], colors: PackedColorArray) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	for i in polygons.size():
		var piece := Polygon2D.new()
		piece.name = "Scrap%d" % i
		piece.polygon = polygons[i]
		piece.color = colors[i]
		layer.add_child(piece)
	return layer
