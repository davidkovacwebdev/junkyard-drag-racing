class_name TreeDatabase
extends RefCounted
## Filesystem helpers for the Tree Creator dock: finds every tree part scene
## under res://scenes/trees/parts (grouped by each part's own TreePartData.slot,
## not by folder name) and every saved tree under res://trees.
##
## Editor-time only on purpose — nothing scans the disk at game runtime. Saved
## TreeData resources hold direct PackedScene references, so runtime code never
## needs this class. Mirrors BuildingDatabase.

const PARTS_ROOT := "res://scenes/trees/parts"
const TREES_ROOT := "res://trees"

## Returns { TreePartData.Slot: [ { "scene": PackedScene, "data": TreePartData }, ... ] }
static func scan_parts() -> Dictionary:
	var by_slot := {}
	for slot in TreePartData.Slot.values():
		by_slot[slot] = []
	for path in _find_files(PARTS_ROOT, ".tscn"):
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var data := _read_part_data(scene)
		if data == null:
			push_warning("TreeDatabase: %s has no TreePartData" % path)
			continue
		by_slot[data.slot].append({ "scene": scene, "data": data })
	for slot in by_slot:
		by_slot[slot].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.data.display_name) < String(b.data.display_name)
		)
	return by_slot

## Resource paths of every saved tree, ready for ResourceLoader.load().
static func list_trees() -> PackedStringArray:
	return _find_files(TREES_ROOT, ".tres")

static func _read_part_data(scene: PackedScene) -> TreePartData:
	var instance := scene.instantiate()
	var data := instance.get("part_data") as TreePartData
	instance.free()
	return data

static func _find_files(root: String, suffix: String) -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(root):
		return found
	for dir_path in _all_dirs(root):
		for file in DirAccess.get_files_at(dir_path):
			if file.ends_with(suffix):
				found.append(dir_path.path_join(file))
	return found

## Breadth-first walk so nested part folders work without recursion limits.
static func _all_dirs(root: String) -> PackedStringArray:
	var dirs := PackedStringArray([root])
	var index := 0
	while index < dirs.size():
		var current := dirs[index]
		index += 1
		for sub in DirAccess.get_directories_at(current):
			dirs.append(current.path_join(sub))
	return dirs
