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

@export_group("Hydraulics")
## Upward speed (px/s) the lowrider rams kick the whole car to on every hop.
## 0 means the body has no hydraulics.
@export var hydraulic_hop_speed: float = 0.0
## How far (px) the rams can push each wheel out below its mount. The body
## rises this far off its wheels before it drags them off the ground.
@export var hydraulic_stroke: float = 0.0
## Seconds the pump needs to recharge after a hop before the next one.
@export var hydraulic_recharge_time: float = 1.4

## Engine power multiplier at the catalog's least and most streamlined body
## (BODY_SPEED_RANGE): a cardboard box holds its engine back, a saucer lets it
## fly.
const SPEED_MULTIPLIER_RANGE := Vector2(0.8, 1.2)
const BODY_SPEED_RANGE := Vector2(1.2, 5.0)

func _init() -> void:
	category = Category.BODY

func effect_summary() -> String:
	if hydraulic_hop_speed > 0.0:
		return "Hydraulics: hops the whole car off the ground every few seconds."
	return ""

## What this body does to the engine's power, from its speed stat.
func speed_multiplier() -> float:
	return lerpf(SPEED_MULTIPLIER_RANGE.x, SPEED_MULTIPLIER_RANGE.y, _normalize(speed, BODY_SPEED_RANGE))
