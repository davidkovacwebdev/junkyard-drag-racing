class_name CarModelData
extends Resource
## One garage-inventory entry, built from real parts — the same
## BodyPartData/EnginePartData/WheelPartData classes the drag-race rig
## uses — instead of a one-off car struct. A body (which may bring its
## own default engine along), plus one WheelPartData per wheel mount.
## A Resource on purpose: this slots straight into ResourceSaver/JSON
## later for save games without restructuring.

@export var body: BodyPartData
@export var engine: EnginePartData
@export var wheels: Array[WheelPartData] = []

## The body IS the car's identity/paint job for now — no separate
## "car name" or "car color" to keep in sync with whatever body is
## equipped.
var display_name: String:
	get: return body.display_name if body != null else "Unnamed Car"

var body_color: Color:
	get: return body.color if body != null else Color.WHITE
