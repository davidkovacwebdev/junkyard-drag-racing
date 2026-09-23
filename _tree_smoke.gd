extends Node
## Throwaway headless smoke test for the tree pipeline. Run with:
##   timeout 60 godot --headless res://_tree_smoke.tscn
## Delete once it has served its purpose.

const TREE_PATHS := [
	"res://trees/oak.tres",
	"res://trees/pine.tres",
	"res://trees/birch.tres",
	"res://trees/palm.tres",
	"res://trees/dead_tree.tres",
]

const COMPOSED_TREE := "res://scenes/world/composed_tree.tscn"

## How far below the ground line a part's art may reach. Trunks draw a soft
## contact shadow that spills a few pixels past y = 0 on purpose.
const SHADOW_SPILL := 6.0

var _failures: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	print("SMOKE %s" % ("FAILED (%d)" % _failures if _failures > 0 else "OK"))
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)

func _run() -> void:
	_check_fallback()
	_check_database()

	var holder := Node2D.new()
	holder.y_sort_enabled = true
	add_child(holder)

	for path in TREE_PATHS:
		await _check_saved_tree(path, holder)

	await _check_sparse(holder)
	await _check_flip(holder)

# --------------------------------------------------------------------------

func _check_fallback() -> void:
	print("fallback footprint")
	var fallback := TreeAssembler.get_footprint_size(null)
	_check(fallback == TreeAssembler.DEFAULT_FOOTPRINT,
		"null tree -> DEFAULT_FOOTPRINT (got %s)" % fallback)

	# A tree with a canopy but no trunk still needs a non-zero collision box,
	# otherwise the car drives straight through it.
	var trunkless := TreeData.new()
	trunkless.display_name = "Trunkless"
	trunkless.canopy_scene = load("res://scenes/trees/parts/canopies/canopy_oak.tscn") as PackedScene
	var trunkless_footprint := TreeAssembler.get_footprint_size(trunkless)
	_check(trunkless_footprint == TreeAssembler.DEFAULT_FOOTPRINT,
		"trunkless tree -> DEFAULT_FOOTPRINT (got %s)" % trunkless_footprint)

func _check_database() -> void:
	print("database scan")
	var by_slot := TreeDatabase.scan_parts()
	for slot in TreePartData.Slot.values():
		var entries: Array = by_slot.get(slot, [])
		print("    %s: %d" % [TreePartData.slot_name(slot), entries.size()])
		_check(entries.size() > 0, "%s has parts" % TreePartData.slot_name(slot))
		for entry in entries:
			_check(entry.data.slot == slot,
				"%s grouped under its own slot (%s)" % [entry.scene.resource_path.get_file(), TreePartData.slot_name(slot)])

	var trees := TreeDatabase.list_trees()
	# Not an exact count: the Tree Creator dock lets new trees be saved at any
	# time, so this only proves the five shipped loadouts are all findable.
	for path in TREE_PATHS:
		_check(trees.has(path), "list_trees finds %s" % path)

func _check_saved_tree(path: String, holder: Node2D) -> void:
	print("tree %s" % path)
	var data := load(path) as TreeData
	if data == null:
		_check(false, "%s loads as TreeData" % path)
		return

	var packed := load(COMPOSED_TREE) as PackedScene
	if packed == null:
		_check(false, "%s loads" % COMPOSED_TREE)
		return

	var tree := packed.instantiate() as ComposedTree
	if tree == null:
		_check(false, "composed_tree root is a ComposedTree")
		return
	tree.tree_data = data
	holder.add_child(tree)
	await get_tree().process_frame
	await get_tree().process_frame

	var frame := "  [%s]" % data.display_name

	# --- the assembled root -------------------------------------------------
	var root := tree.get_node_or_null(NodePath(data.display_name)) as Node2D
	_check(root != null, "%s assembled root named after display_name" % frame)
	if root == null:
		return
	_check(root.get_child_count() == 3,
		"%s assembled 3 parts (got %d)" % [frame, root.get_child_count()])
	for slot in TreePartData.Slot.values():
		var part_name := "%sPart" % TreePartData.slot_name(slot)
		_check(root.get_node_or_null(NodePath(part_name)) != null,
			"%s has %s" % [frame, part_name])

	# --- draw order: trunk behind canopy behind decoration ------------------
	var trunk := root.get_node_or_null("TrunkPart")
	var canopy := root.get_node_or_null("CanopyPart")
	var deco := root.get_node_or_null("DecorationPart")
	if trunk != null and canopy != null and deco != null:
		_check(trunk.z_index < canopy.z_index and canopy.z_index < deco.z_index,
			"%s draw order trunk < canopy < decoration (%d/%d/%d)"
				% [frame, trunk.z_index, canopy.z_index, deco.z_index])

	# --- collision hugs the ground -----------------------------------------
	var footprint := TreeAssembler.get_footprint_size(data)
	if trunk != null:
		_check(footprint == trunk.footprint_size,
			"%s footprint comes from the trunk part" % frame)
	var expected_height := footprint.y * data.collision_height_fraction
	var collision := tree.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check(collision != null, "%s has a CollisionShape2D" % frame)
	if collision != null:
		_check(collision.shape is ConvexPolygonShape2D or collision.shape is RectangleShape2D,
			"%s collision shape built" % frame)
		_check(is_equal_approx(collision.position.y, -expected_height / 2.0),
			"%s collision centred above ground (%.2f vs %.2f)"
				% [frame, collision.position.y, -expected_height / 2.0])
		_check(collision.position.y <= 0.0, "%s collision never dips below y=0" % frame)

	# --- art sits above the ground -----------------------------------------
	# Every trunk draws a soft contact shadow that deliberately spills a few
	# pixels below y = 0 (there is no drawn ground plane, so it just marks
	# where the trunk meets the ground). SHADOW_SPILL is the allowance for
	# that; anything past it means art was authored below ground by accident.
	var lowest := 0.0
	for part in root.get_children():
		for poly in part.get_children():
			if poly is Polygon2D:
				for point in (poly as Polygon2D).polygon:
					lowest = maxf(lowest, (part as Node2D).position.y + point.y)
	_check(lowest <= SHADOW_SPILL,
		"%s art stays at the ground line (lowest y = %.1f, allowance %.1f)"
			% [frame, lowest, SHADOW_SPILL])

	holder.remove_child(tree)
	tree.free()

## A trunk + canopy with no decoration is the most common tree (the dock's
## Randomize leaves the decoration empty sometimes, and Save As from a fresh
## New Tree has none at all), so prove the assembler skips that slot cleanly
## instead of leaving a hole or a null part behind.
func _check_sparse(holder: Node2D) -> void:
	print("sparse tree (no decoration)")
	var data := TreeData.new()
	data.display_name = "Sparse"
	data.trunk_scene = load("res://scenes/trees/parts/trunks/trunk_pine.tscn") as PackedScene
	data.canopy_scene = load("res://scenes/trees/parts/canopies/canopy_pine.tscn") as PackedScene

	var packed := load(COMPOSED_TREE) as PackedScene
	var tree := packed.instantiate() as ComposedTree
	tree.tree_data = data
	holder.add_child(tree)
	await get_tree().process_frame

	var root := tree.get_node_or_null("Sparse") as Node2D
	_check(root != null, "sparse tree assembled a root")
	if root != null:
		_check(root.get_child_count() == 2,
			"sparse tree assembles 2 parts (got %d)" % root.get_child_count())
		_check(root.get_node_or_null("DecorationPart") == null,
			"sparse tree has no DecorationPart")

	holder.remove_child(tree)
	tree.free()

func _check_flip(holder: Node2D) -> void:
	print("flip_h")
	var data := load(TREE_PATHS[0]) as TreeData
	var packed := load(COMPOSED_TREE) as PackedScene
	var tree := packed.instantiate() as ComposedTree
	tree.tree_data = data
	tree.flip_h = true
	holder.add_child(tree)
	await get_tree().process_frame
	await get_tree().process_frame

	var root := tree.get_node_or_null(NodePath(data.display_name)) as Node2D
	_check(root != null and is_equal_approx(root.scale.x, -1.0),
		"flip_h mirrors the assembled root (scale.x = %s)" % (root.scale.x if root != null else "n/a"))
	# The collision box must NOT mirror — mirroring it is harmless for a
	# symmetric box, but it signals the flip leaked out of the art.
	var collision := tree.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check(collision != null and is_equal_approx(collision.scale.x, 1.0),
		"flip_h leaves the collision box alone")

	holder.remove_child(tree)
	tree.free()
