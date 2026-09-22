class_name ComposedBuilding
extends Obstacle
## A building assembled at runtime from a BuildingData loadout — the
## Building Creator's counterpart to how CarAssembler turns a saved car
## loadout into an actual car. The "Press E to enter" interaction and
## interior_scene/test_interior_scene are inherited from Obstacle
## unchanged; this adds the part-swapping visual, and deliberately does
## NOT call Obstacle._ready() — see below.

@export var building_data: BuildingData

func _ready() -> void:
	if building_data != null:
		size = BuildingAssembler.get_footprint_size(building_data)
		collision_height_fraction = building_data.collision_height_fraction
		corner_radius = building_data.corner_radius

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
	var collision_height := size.y * collision_height_fraction
	var sort_offset := size.y / 2.0 - collision_height
	position.y += sort_offset

	$CollisionShape2D.shape = RoundedRectShape.build(Vector2(size.x, collision_height), corner_radius)
	$CollisionShape2D.position = Vector2(0.0, collision_height / 2.0)

	# Ground line, in this shifted local space: one collision_height below
	# the node's new origin, matching where every part's own building-space
	# origin (y=0) expects to land.
	BuildingAssembler.assemble(building_data, self, Vector2(0.0, collision_height))
