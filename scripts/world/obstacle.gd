class_name Obstacle
extends StaticBody2D
## A solid rectangle you can drive into — placeholder junkyard debris, and
## a visible landmark so movement/rotation are obvious against the empty
## sand (the camera is a child of the car, so the car itself never moves
## on screen; these are what give you something to move relative to).
##
## Buildings are meant to read as 3D — a footprint you can't drive
## through, with a taller "front wall" rising above it that you *can*
## walk behind. So the collision only covers the bottom slice of the
## visual (the footprint); the rest is walkable-behind, and Main's
## y_sort_enabled draws whichever of the car/building has the lower Y
## first, so the car slots visually behind the wall when it's above it
## and in front of it when it's below.

@export var size: Vector2 = Vector2(200, 200)
@export var rect_color: Color = Color(0.45, 0.35, 0.25)
## Non-empty makes this interactable: the player gets a "Press space to
## enter" tooltip near it and its name is what gets printed on activation.
@export var display_name: String = ""
## Optional: if set, activating this also switches to that scene (e.g.
## the garage interior).
@export var interior_scene: PackedScene
## Fraction of the visual height that's actually solid, hugging the
## bottom edge — the building's footprint. Set to 1.0 for a flat prop
## with no "behind it" to walk into.
@export_range(0.0, 1.0) var collision_height_fraction: float = 0.35
## How rounded the collision footprint's corners are — see RoundedRectShape.
## Keeps the car from catching and stopping dead on a sharp corner; it slides
## past instead.
@export_range(0.0, 100.0) var corner_radius: float = 20.0

func _ready() -> void:
	# `ColorRect` is optional: a subclass scene may draw its own art in
	# _draw() instead (see RegistrationBooth), in which case there's no
	# placeholder rect to size — only the collision shape still needs it.
	var visual: ColorRect = get_node_or_null("ColorRect")
	if visual != null:
		visual.color = rect_color
		visual.size = size
		visual.position = -size / 2.0
	var collision_height := size.y * collision_height_fraction
	$CollisionShape2D.shape = RoundedRectShape.build(Vector2(size.x, collision_height), corner_radius)
	$CollisionShape2D.position = Vector2(0.0, size.y / 2.0 - collision_height / 2.0)
