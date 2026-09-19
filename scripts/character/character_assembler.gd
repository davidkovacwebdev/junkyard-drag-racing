class_name CharacterAssembler
extends RefCounted
## Builds a character from a CharacterData loadout as a plain Node2D tree.
##
## Unlike CarAssembler there are no physics bodies or PinJoint2Ds — a
## character is pure polygons, so assembling is just instancing the part
## chosen for each slot and stacking its draw order. Because every part is
## authored in the same character space (origin at the feet, +y down), no
## anchor math is needed: a part's authored position and rotation are kept
## as-is, exactly like the engine scene's authored offset on a car.

## Draw order for each slot. Later slots draw on top of earlier ones; a
## part's own z_offset nudges it from there (a backpack, say, can drop
## behind the torso).
static func base_z(slot: CharacterPartData.Slot) -> int:
	match slot:
		CharacterPartData.Slot.LEGS:
			return 0
		CharacterPartData.Slot.BOOTS:
			return 1
		CharacterPartData.Slot.TORSO:
			return 2
		CharacterPartData.Slot.HEAD:
			return 3
		CharacterPartData.Slot.HAIR:
			return 4
		CharacterPartData.Slot.EYES:
			return 5
		CharacterPartData.Slot.ACCESSORY:
			return 6
	return 0

## Instances and wires every chosen part under a new root Node2D added to
## `parent` at `spawn_position`. Slots with no part (null scene) are
## skipped, so a character can be as complete or as bare as you like.
static func assemble(data: CharacterData, parent: Node, spawn_position: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = _root_name(data)
	root.position = spawn_position
	parent.add_child(root)

	if data == null:
		return root

	for slot in CharacterPartData.Slot.values():
		var scene := data.get_part(slot)
		if scene == null:
			continue
		var instance := scene.instantiate()
		if not (instance is Node2D):
			push_warning("CharacterAssembler: part for slot %s is not a Node2D" % CharacterPartData.slot_name(slot))
			instance.free()
			continue
		var part := instance as Node2D
		var part_data := part.get("part_data") as CharacterPartData
		part.z_index = base_z(slot) + (part_data.z_offset if part_data != null else 0)
		part.name = "%sPart" % CharacterPartData.slot_name(slot)
		root.add_child(part)

	return root

static func _root_name(data: CharacterData) -> String:
	if data != null:
		var trimmed := data.display_name.strip_edges()
		if not trimmed.is_empty():
			return trimmed
	return "Character"
