class_name FlexArm
extends Node2D
## Spike's flexing arm in the race office (DragStripMenu): stands in for the
## torso's own left arm while he shows off. Drawn in character space, so it
## sits on the rig: the upper arm sticks straight out from the shoulder, the
## forearm points up to a fist, and the biceps bulge (`bulge`, 0-1) swells
## on top.
##
## Junk-toy style: upper arm, forearm, fist, biceps bump.

const SHOULDER := Vector2(-26.0, -170.0)
const ELBOW := Vector2(-80.0, -164.0)
const FIST := Vector2(-74.0, -224.0)
const THICK := 18.0
const BICEPS_AT := Vector2(-54.0, -178.0)
const BICEPS_SIZE := Vector2(17.0, 9.0)

var sleeve := Color(0.16, 0.16, 0.2, 1)
var skin := Color(0.85, 0.68, 0.52, 1)
## 0 relaxed, 1 fully pumped.
var bulge := 0.0:
	set(value):
		bulge = value
		queue_redraw()

func _draw() -> void:
	draw_colored_polygon(FlatProps.sliver(SHOULDER, ELBOW, THICK), sleeve)
	draw_colored_polygon(FlatProps.sliver(ELBOW + Vector2(0.0, THICK * 0.5), FIST, THICK), sleeve)
	var size := BICEPS_SIZE * (1.0 + bulge * 0.9)
	draw_colored_polygon(FlatProps.octagon(BICEPS_AT + Vector2(0.0, -size.y * 0.4), size.x, size.y), sleeve)
	draw_colored_polygon(FlatProps.octagon(FIST + Vector2(0.0, -6.0), 12.0, 11.0), skin)
