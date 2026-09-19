class_name CarModelData
extends Resource
## One garage-inventory entry. A Resource rather than a plain dict/class
## on purpose: an Array[CarModelData] can be handed straight to
## ResourceSaver/JSON later for save games without restructuring.

@export var id: StringName
@export var display_name: String = ""
@export var body_color: Color = Color.WHITE
