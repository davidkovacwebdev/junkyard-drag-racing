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
## False for bodies hidden somewhere on the map (the hangar's flying saucer)
## rather than dug out of bins and junk heaps.
@export var found_in_junk: bool = true

@export_group("Suspension")
## How far (px) the body settles onto each wheel's spring under its own
## weight. Bigger is softer.
@export var suspension_sag: float = 6.0
## How far (px) each wheel can move up or down from its mount before it
## hits the stop.
@export var suspension_travel: float = 14.0
## 1 settles without bouncing, lower bounces, higher feels stiff and slow.
@export var suspension_damping_ratio: float = 0.7
## 0..1 share of every wheel's damage from hitting the ground (bumps,
## landings) the springs soak up, on top of the wheel's own absorption.
## Hits from other cars go through in full.
@export_range(0.0, 0.9) var suspension_wheel_protection: float = 0.3

func _init() -> void:
	category = Category.BODY
