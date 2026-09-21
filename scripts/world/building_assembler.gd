class_name BuildingAssembler
extends RefCounted
## Builds a building from a BuildingData loadout as a plain Node2D tree.
##
## Like CharacterAssembler there are no physics bodies here — a building's
## art is pure polygons, so assembling is just instancing the part chosen
## for each slot and stacking its draw order. Every part is authored in
## the same "building space" (origin at the ground, +y down), so no
## anchor math is needed: a part's authored position and rotation are
## kept as-is.

const DEFAULT_FOOTPRINT := Vector2(200.0, 200.0)

## Draw order for each slot. Later slots draw on top of earlier ones; a
## part's own z_offset nudges it from there (a decoration can, say, sit
## behind the wall instead of in front of it).
static func base_z(slot: BuildingPartData.Slot) -> int:
	match slot:
		BuildingPartData.Slot.WALL:
			return 0
		BuildingPartData.Slot.WINDOW:
			return 1
		BuildingPartData.Slot.DOOR:
			return 2
		BuildingPartData.Slot.DECORATION:
			return 3
		BuildingPartData.Slot.ROOF:
			return 4
	return 0

## Instances and wires every chosen part under a new root Node2D added to
## `parent` at `spawn_position`. Slots with no part (null scene) are
## skipped, so a building can be as complete or as bare as you like.
static func assemble(data: BuildingData, parent: Node, spawn_position: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = _root_name(data)
	root.position = spawn_position
	parent.add_child(root)

	if data == null:
		return root

	for slot in BuildingPartData.Slot.values():
		var scene := data.get_part(slot)
		if scene == null:
			continue
		var instance := scene.instantiate()
		if not (instance is Node2D):
			push_warning("BuildingAssembler: part for slot %s is not a Node2D" % BuildingPartData.slot_name(slot))
			instance.free()
			continue
		var part := instance as Node2D
		var part_data := part.get("part_data") as BuildingPartData
		part.z_index = base_z(slot) + (part_data.z_offset if part_data != null else 0)
		part.name = "%sPart" % BuildingPartData.slot_name(slot)
		root.add_child(part)

	return root

## The building's footprint (width, height-above-ground), read off its
## WALL part — that's the part that actually defines how big the building
## reads as. Falls back to DEFAULT_FOOTPRINT for a wall-less building (or
## one with no data at all) so a decoration-only prop still gets a sane
## collision box instead of a zero-size one.
static func get_footprint_size(data: BuildingData) -> Vector2:
	if data == null or data.wall_scene == null:
		return DEFAULT_FOOTPRINT
	var instance := data.wall_scene.instantiate()
	var footprint: Vector2 = instance.get("footprint_size")
	instance.free()
	if footprint == null or footprint == Vector2.ZERO:
		return DEFAULT_FOOTPRINT
	return footprint

static func _root_name(data: BuildingData) -> String:
	if data != null:
		var trimmed := data.display_name.strip_edges()
		if not trimmed.is_empty():
			return trimmed
	return "Building"
