@tool
class_name HillClimbTrack
extends RallyTrack
## The hill climb: the rally's five lanes, but the road only goes up, and gets
## steeper the higher it goes, before a short crest onto a flat summit. Same
## node layout and the same surface_offset_at() contract as RallyTrack, so the
## race setup, collision and hazards all work on it unchanged.
##
## The slope is laid out as its grade (rise per run) at a few x's, eased
## linearly between them, and the height is that grade added up along x.

## Where the road leaves the flat start and where it tops out.
@export var climb_start := 500.0
@export var summit_x := 3300.0
## Grade at the foot of the hill and just under the crest (1.0 is 45°).
@export var foot_grade := 0.35
@export var crest_grade := 1.0
## How long the road takes to ease into the climb, and over the crest.
@export var ease_in_length := 300.0
@export var crest_length := 220.0

## The summit's end wall is authored at lane height; it's lifted onto the
## summit here, so retuning the slope never leaves it floating or buried.
func _ready() -> void:
	super()
	var wall := get_node_or_null("EndWall") as Node2D
	if wall != null and not Engine.is_editor_hint():
		wall.position.y += surface_offset_at(wall.position.x)

func surface_offset_at(x: float) -> float:
	var knots := _grade_knots()
	var height := 0.0
	for i in knots.size() - 1:
		var from := knots[i]
		var to := knots[i + 1]
		if x <= from.x:
			break
		var run := minf(x, to.x) - from.x
		var grade_change := (to.y - from.y) / (to.x - from.x)
		height += from.y * run + grade_change * run * run * 0.5
	return -height

## Height climbed by the summit, in px (positive).
func summit_height() -> float:
	return -surface_offset_at(summit_x)

## The first x the road has climbed `height` px at, or the summit if never.
func x_at_height(height: float) -> float:
	for x in sample_xs():
		if -surface_offset_at(x) >= height:
			return x
	return summit_x

## (x, grade) pairs, with flat road before the first and after the last.
func _grade_knots() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(climb_start, 0.0),
		Vector2(climb_start + ease_in_length, foot_grade),
		Vector2(summit_x - crest_length, crest_grade),
		Vector2(summit_x, 0.0),
	])
