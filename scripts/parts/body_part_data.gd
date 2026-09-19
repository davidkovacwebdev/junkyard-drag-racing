class_name BodyPartData
extends PartData
## Mount points themselves live in the body's scene as Marker2D children
## named "WheelMount*" so they can be placed visually in the editor.

@export var max_wheels: int = 2
## What CarVisual actually paints the body polygon with.
@export var color: Color = Color.WHITE
## If set, a car built with this body comes with this engine already
## installed (a fridge's built-in compressor motor, say). Left null, the
## body ships engineless and needs one equipped separately.
@export var default_engine: EnginePartData

func _init() -> void:
	category = Category.BODY
