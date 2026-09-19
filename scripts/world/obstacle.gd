class_name Obstacle
extends StaticBody2D
## A solid rectangle you can drive into — placeholder junkyard debris, and
## a visible landmark so movement/rotation are obvious against the empty
## sand (the camera is a child of the car, so the car itself never moves
## on screen; these are what give you something to move relative to).

@export var size: Vector2 = Vector2(200, 200)
@export var rect_color: Color = Color(0.45, 0.35, 0.25)
## Non-empty makes this interactable: the player gets a "Press space to
## enter" tooltip near it and its name is what gets printed on activation.
@export var display_name: String = ""
## Optional: if set, activating this also switches to that scene (e.g.
## the garage interior).
@export var interior_scene: PackedScene

func _ready() -> void:
	# `ColorRect` is optional: a subclass scene may draw its own art in
	# _draw() instead (see RegistrationBooth), in which case there's no
	# placeholder rect to size — only the collision shape still needs it.
	var visual: ColorRect = get_node_or_null("ColorRect")
	if visual != null:
		visual.color = rect_color
		visual.size = size
		visual.position = -size / 2.0
	var shape: RectangleShape2D = $CollisionShape2D.shape
	shape.size = size
