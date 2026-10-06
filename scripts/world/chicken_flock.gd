class_name ChickenFlock
extends Node2D
## A handful of chickens loose in a pen of `pen_size`, centred on this node.
## They're its children, so this node is Y-sorted and they sort against the car
## and the farm props around them (see Chicken).

@export var count: int = 6
@export var pen_size: Vector2 = Vector2(480, 200)

func _ready() -> void:
	y_sort_enabled = true
	var pen := Rect2(global_position - pen_size * 0.5, pen_size)
	for i in count:
		var chicken := Chicken.new()
		chicken.pen = pen
		chicken.position = Vector2(randf_range(-0.5, 0.5) * pen_size.x, randf_range(-0.5, 0.5) * pen_size.y)
		add_child(chicken)
