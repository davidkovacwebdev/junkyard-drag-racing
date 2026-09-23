@tool
class_name ComposedBuilding
extends Obstacle
## A building assembled at runtime from a BuildingData loadout — the
## Building Creator's counterpart to how CarAssembler turns a saved car
## loadout into an actual car. The "Press E to enter" interaction and
## interior_scene/test_interior_scene are inherited from Obstacle
## unchanged; this adds the part-swapping visual, and deliberately does
## NOT call Obstacle._ready() — see below.
##
## @tool so a hand-placed building is visible in the 2D editor instead of
## showing up as an empty StaticBody2D. The assembled art root is added with no
## `owner`, so it shows in the viewport but is never written into the saved
## scene, and the editor preview deliberately leaves the node's transform and
## collision untouched — see `_assemble()`. At runtime nothing changes.

@export var building_data: BuildingData:
	set(value):
		building_data = value
		if is_node_ready():
			_assemble()

## The assembled art root, so a re-assemble drops the old one instead of
## stacking a second building on top of it.
var _art: Node2D
## The y-sort shift already baked into `position`, so a re-assemble (e.g. the
## loadout changing at runtime) adjusts by the difference rather than adding a
## second shift on top of the first.
var _applied_sort_offset: float = 0.0

func _ready() -> void:
	_assemble()

func _assemble() -> void:
	_clear_art()

	# Selected properties, held as locals so the editor preview never writes the
	# derived values back into the exported ones (which would dirty the .tscn).
	var building_size := size
	var fraction := collision_height_fraction
	var corner := corner_radius
	if building_data != null:
		building_size = BuildingAssembler.get_footprint_size(building_data)
		fraction = building_data.collision_height_fraction
		corner = building_data.corner_radius

	var collision_height := building_size.y * fraction
	# Where the building's ground line sits relative to the authored origin:
	# the footprint is (width, height-above-ground), so its ground is half the
	# height below the visual centre the node is authored at.
	var ground_local := building_size.y / 2.0
	var sort_offset := ground_local - collision_height

	if Engine.is_editor_hint():
		# Preview only: place the art exactly where it lands at runtime, but do
		# it relative to the authored origin. The node's own transform and its
		# collision shape are left completely alone, because the runtime shift
		# below is a y-sort fix that must not be saved into the scene.
		_art = BuildingAssembler.assemble(building_data, self, Vector2(0.0, ground_local))
		return

	# Obstacle._ready() centres the collision box on the node's own origin,
	# which is also the point Main's y_sort_enabled reads to decide whether
	# the car draws in front of or behind this building. On a tall, roofed
	# building that leaves a dead band between the box's visual centre and
	# the collision footprint's actual top edge, where the car pops in
	# front on screen while still standing well above the wall — reported
	# as the car floating "above the house". Fixed by shifting this body
	# down onto the collision footprint's top edge, then pulling the
	# collision shape and the assembled visuals back up by the same
	# amount, so every pixel lands exactly where Obstacle would have put
	# it — only the sort key moves. Skipping super._ready() (rather than
	# patching this into Obstacle itself) keeps House/RegistrationBooth,
	# which draw straight off Obstacle's own box-centred convention,
	# completely unaffected.
	size = building_size
	collision_height_fraction = fraction
	corner_radius = corner
	position.y += sort_offset - _applied_sort_offset
	_applied_sort_offset = sort_offset

	$CollisionShape2D.shape = RoundedRectShape.build(Vector2(building_size.x, collision_height), corner)
	$CollisionShape2D.position = Vector2(0.0, collision_height / 2.0)

	# Ground line, in this shifted local space: one collision_height below
	# the node's new origin, matching where every part's own building-space
	# origin (y=0) expects to land.
	_art = BuildingAssembler.assemble(building_data, self, Vector2(0.0, collision_height))

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
