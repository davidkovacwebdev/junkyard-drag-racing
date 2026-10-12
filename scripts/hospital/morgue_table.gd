class_name MorgueTable
extends Node2D
## The steel slab in the hospital morgue. Grandpa lies on it pancaked flat
## from the crane (HospitalMorgueCutscene puts him there, at `body_spot()`).
## Origin on the floor under the middle of the slab, so it Y-sorts against
## the people standing round it.

const STEEL := Color(0.66, 0.68, 0.7, 1)
const STEEL_SHADE := Color(0.5, 0.52, 0.55, 1)

@export var length: float = 300.0
@export var height: float = 92.0

func _draw() -> void:
	var half := length * 0.5
	draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, half + 10.0, 14.0), UiPalette.SHADOW)
	# Two chunky legs, the slab, and its front edge in shade.
	draw_rect(Rect2(-half + 26.0, -height, 16.0, height), STEEL_SHADE)
	draw_rect(Rect2(half - 42.0, -height, 16.0, height), STEEL_SHADE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half, -height - 26.0), Vector2(half, -height - 28.0),
		Vector2(half + 4.0, -height), Vector2(-half - 2.0, -height + 2.0),
	]), STEEL)
	draw_rect(Rect2(-half - 2.0, -height, length + 6.0, 10.0), STEEL_SHADE)

## Where a body lies on the slab, in this node's space: the middle of its top.
func body_spot() -> Vector2:
	return Vector2(0.0, -height - 12.0)
