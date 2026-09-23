@tool
class_name ComposedTree
extends StaticBody2D
## A tree assembled at runtime from a TreeData loadout — the Tree Creator's
## counterpart to how ComposedBuilding turns a saved building loadout into an
## actual building.
##
## **Art space**: origin at the trunk's ground contact point, all art drawn
## above it (negative Y). Deliberately NOT an `Obstacle`, which centres its
## art on the origin — a tree's base is its Y-sort key, exactly like the car's
## own origin, so a tree dropped into a Y-sorted layer (Main's `Sortables`)
## draws in front of the car when the car is above it and behind it when the
## car is below. TrashProp follows the same convention for the same reason.
##
## Collision is the trunk's own footprint, hugging the ground: the car bumps
## the trunk and drives under the canopy. The footprint's width and height come
## off the chosen trunk part (see TreePart.footprint_size), so a sapling and a
## fat oak each get their own size.

## @tool so a hand-placed tree is visible in the 2D editor instead of showing
## up as an empty StaticBody2D. The art is still assembled the same way at
## runtime — editor mode just also draws it, and re-draws when the loadout
## changes. The assembled art root is added with no `owner`, so it lives in the
## editor viewport but is never written into the saved scene.
@export var tree_data: TreeData:
	set(value):
		tree_data = value
		if is_node_ready():
			_assemble()

## Mirror the whole tree horizontally. One saved tree placed a few times reads
## as a stand of different trees once some of them are flipped, which is what
## hand-placing a forest wants.
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		if is_node_ready():
			_mirror()

## The assembled art root, kept so a re-assemble can drop the old one instead of
## stacking a second tree on top of it.
var _art: Node2D

func _ready() -> void:
	_assemble()

## (Re)build the harness: collision footprint first, then the art. Cheap and
## idempotent — it frees any previous art root before making a new one, so the
## editor can call it on every loadout change without piling up trees.
func _assemble() -> void:
	_clear_art()

	var footprint := TreeAssembler.get_footprint_size(tree_data)
	var fraction := tree_data.collision_height_fraction if tree_data != null else 1.0
	var corner_radius := tree_data.corner_radius if tree_data != null else 0.0
	var collision_height := footprint.y * fraction
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	# Editor builds the art only. Writing a fresh CollisionShape resource here
	# would replace the authored sub-resource every time the scene is opened,
	# dirtying the .tscn for no visual gain — the collision is fully derived from
	# `tree_data`, so it is rebuilt at runtime regardless.
	if collision != null and not Engine.is_editor_hint():
		collision.shape = RoundedRectShape.build(Vector2(footprint.x, collision_height), corner_radius)
		# Hug the ground: the box grows upward from the origin (y = 0), so its
		# centre sits one half-height above the ground line and never below it.
		collision.position = Vector2(0.0, -collision_height / 2.0)

	_art = TreeAssembler.assemble(tree_data, self, Vector2.ZERO)
	_mirror()

## Flip the art to match `flip_h`. Separate from `_assemble()` so toggling the
## flip doesn't have to tear the tree down and rebuild it.
func _mirror() -> void:
	if _art != null and is_instance_valid(_art):
		_art.scale.x = -1.0 if flip_h else 1.0

## Drop the currently assembled art, if any. Uses `free()` rather than
## `queue_free()` so a re-assemble in the same frame can't briefly show both.
func _clear_art() -> void:
	if _art == null or not is_instance_valid(_art):
		_art = null
		return
	if _art.get_parent() != null:
		_art.get_parent().remove_child(_art)
	_art.free()
	_art = null
