class_name BodyPartData
extends PartData
## Mount points themselves live in the body's scene as Marker2D children
## named "WheelMount*" so they can be placed visually in the editor.

@export var max_wheels: int = 2

func _init() -> void:
	category = Category.BODY
