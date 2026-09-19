class_name Obstacle
extends StaticBody2D
## A solid rectangle you can drive into — placeholder junkyard debris, and
## a visible landmark so movement/rotation are obvious against the empty
## sand (the camera is a child of the car, so the car itself never moves
## on screen; these are what give you something to move relative to).

@export var size: Vector2 = Vector2(200, 200)
@export var rect_color: Color = Color(0.45, 0.35, 0.25)

func _ready() -> void:
	var visual: ColorRect = $ColorRect
	visual.color = rect_color
	visual.size = size
	visual.position = -size / 2.0
	var shape: RectangleShape2D = $CollisionShape2D.shape
	shape.size = size
