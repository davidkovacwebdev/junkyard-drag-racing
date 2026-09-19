class_name BackButton
extends Button
## Plain-text "leave this interior" control — flat, no background, just
## a font-color change on hover — dropped into every building interior
## (garage, and whatever comes next) to return to the open world. The
## player lands back at the exact spot they entered from because
## PlayerCar/WorldState handle that, not this button.

func _pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")
