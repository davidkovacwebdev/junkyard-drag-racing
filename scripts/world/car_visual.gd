class_name CarVisual
extends Node2D
## Shared side-view car silhouette. Used both by the drivable PlayerCar
## and by the garage preview, so the shape only has to live in one place.

@export var body_color: Color = Color(0.6, 0.15, 0.15, 1)

func _ready() -> void:
	_apply_color()

func set_body_color(color: Color) -> void:
	body_color = color
	_apply_color()

func _apply_color() -> void:
	$Body.color = body_color
