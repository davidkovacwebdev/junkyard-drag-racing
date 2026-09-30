class_name CharacterDatabase
extends RefCounted
## Filesystem helpers: finds every character part scene under
## res://scenes/characters/parts (grouped by each part's own
## CharacterPartData.slot, not by folder name) and every saved character
## under res://characters.
##
## The Character Creator dock uses it in the editor, and the player's
## character creation screen uses `scan_player_parts()` at runtime. Listing
## goes through ResourceLoader.list_directory() rather than DirAccess, so it
## still finds the parts in an exported build, where scenes are remapped.
## Saved CharacterData resources hold direct PackedScene references, so
## loading a character never needs this class.

const PARTS_ROOT := "res://scenes/characters/parts"
const CHARACTERS_ROOT := "res://characters"

## Returns { CharacterPartData.Slot: [ { "scene": PackedScene, "data": CharacterPartData }, ... ] }
static func scan_parts() -> Dictionary:
	var by_slot := {}
	for slot in CharacterPartData.Slot.values():
		by_slot[slot] = []
	for path in _find_files(PARTS_ROOT, ".tscn"):
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var data := _read_part_data(scene)
		if data == null:
			push_warning("CharacterDatabase: %s has no CharacterPartData" % path)
			continue
		by_slot[data.slot].append({ "scene": scene, "data": data })
	for slot in by_slot:
		by_slot[slot].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.data.display_name) < String(b.data.display_name)
		)
	return by_slot

## Same as scan_parts(), minus the parts reserved for NPCs (`npc_only`).
static func scan_player_parts() -> Dictionary:
	var by_slot := scan_parts()
	for slot in by_slot:
		by_slot[slot] = (by_slot[slot] as Array).filter(func(entry: Dictionary) -> bool:
			return not (entry.data as CharacterPartData).npc_only
		)
	return by_slot

## Resource paths of every saved character, ready for ResourceLoader.load().
static func list_characters() -> PackedStringArray:
	return _find_files(CHARACTERS_ROOT, ".tres")

static func _read_part_data(scene: PackedScene) -> CharacterPartData:
	var instance := scene.instantiate()
	var data := instance.get("part_data") as CharacterPartData
	instance.free()
	return data

static func _find_files(root: String, suffix: String) -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(root):
		return found
	for dir_path in _all_dirs(root):
		for entry in ResourceLoader.list_directory(dir_path):
			if entry.ends_with(suffix):
				found.append(dir_path.path_join(entry))
	return found

## Breadth-first walk so nested part folders work without recursion limits.
static func _all_dirs(root: String) -> PackedStringArray:
	var dirs := PackedStringArray([root])
	var index := 0
	while index < dirs.size():
		var current := dirs[index]
		index += 1
		for entry in ResourceLoader.list_directory(current):
			if entry.ends_with("/"):
				dirs.append(current.path_join(entry.trim_suffix("/")))
	return dirs
