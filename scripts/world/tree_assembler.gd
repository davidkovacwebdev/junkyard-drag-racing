class_name TreeAssembler
extends RefCounted
## Builds a tree from a TreeData loadout as a plain Node2D tree.
##
## Like BuildingAssembler there are no physics bodies here — a tree's art is
## pure polygons, so assembling is just instancing the part chosen for each
## slot and stacking its draw order. Every part is authored in the same
## "tree space" (origin at the ground, +y down), so no anchor math is needed:
## a part's authored position and rotation are kept as-is.

## Fallback trunk footprint for a trunk-less tree (or one with no data at
## all), so a canopy-only prop still gets a sane collision box instead of a
## zero-size one. Mirrors BuildingAssembler.DEFAULT_FOOTPRINT.
const DEFAULT_FOOTPRINT := Vector2(48.0, 34.0)

## Draw order for each slot (as child order). Later slots draw on top of
## earlier ones; a part's own z_offset nudges it from there (a decoration can, say, sit
## behind the trunk instead of in front of it).
static func base_z(slot: TreePartData.Slot) -> int:
	match slot:
		TreePartData.Slot.TRUNK:
			return 0
		TreePartData.Slot.CANOPY:
			return 1
		TreePartData.Slot.DECORATION:
			return 2
	return 0

## Instances and wires every chosen part under a new root Node2D added to
## `parent` at `spawn_position`. Slots with no part (null scene) are skipped,
## so a tree can be as complete or as bare as you like.
static func assemble(data: TreeData, parent: Node, spawn_position: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = _root_name(data)
	root.position = spawn_position
	parent.add_child(root)

	if data == null:
		return root

	var ordered_parts: Array[Array] = []
	for slot in TreePartData.Slot.values():
		var scene := data.get_part(slot)
		if scene == null:
			continue
		var instance := scene.instantiate()
		if not (instance is Node2D):
			push_warning("TreeAssembler: part for slot %s is not a Node2D" % TreePartData.slot_name(slot))
			instance.free()
			continue
		var part := instance as Node2D
		var part_data := part.get("part_data") as TreePartData
		part.name = "%sPart" % TreePartData.slot_name(slot)
		ordered_parts.append([base_z(slot) + (part_data.z_offset if part_data != null else 0), part])
	# Layered by child order, not z_index: a raised z_index lifts the part out of
	# Main's y-sort, so the canopy would draw over a car parked in front of it.
	ordered_parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry in ordered_parts:
		root.add_child(entry[1])

	return root

## The tree's footprint (width, height-above-ground), read off its TRUNK part
## — that's the part that actually defines how much of the tree is solid.
## Falls back to DEFAULT_FOOTPRINT for a trunk-less tree (or one with no data
## at all) so a canopy-only prop still gets a sane collision box instead of a
## zero-size one.
static func get_footprint_size(data: TreeData) -> Vector2:
	if data == null or data.trunk_scene == null:
		return DEFAULT_FOOTPRINT
	var instance := data.trunk_scene.instantiate()
	var footprint: Vector2 = instance.get("footprint_size")
	instance.free()
	if footprint == null or footprint == Vector2.ZERO:
		return DEFAULT_FOOTPRINT
	return footprint

static func _root_name(data: TreeData) -> String:
	if data != null:
		var trimmed := data.display_name.strip_edges()
		if not trimmed.is_empty():
			return trimmed
	return "Tree"
