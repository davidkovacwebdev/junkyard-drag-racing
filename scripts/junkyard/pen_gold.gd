class_name PenGold
extends Node2D
## Whatever Eugen saw at the bottom of the junkyard heap: the corner of
## something gold, barely poking up out of the pen floor once the player has
## stirred the junk enough ("Dig Deeper", CranePen). A low slab of gold with
## one shade strip, and a glint that winks now and then over its top corner.
## Drawn behind the junk, so the pieces lying around can hide it: the player
## has to spot it, not just be told. The glint is drawn over the junk, so even
## a slab that's buried deep twinkles through now and then. `uncover()` brings
## the slab out on top once it's found.
##
## Origin `SORT_LIFT` above the pen floor, art drawn down on the floor: the
## Yard is Y-sorted, so junk lying lower than the origin draws over it.

const GOLD := Color(0.86, 0.72, 0.3, 1)
const GOLD_SHADE := Color(0.68, 0.55, 0.2, 1)
const GLINT := Color(1.0, 0.98, 0.88, 1)
## Only a corner sticks up, tipped a little: the rest runs on down under the
## pen.
const SLAB := [Vector2(-40.0, 0.0), Vector2(-30.0, -24.0), Vector2(26.0, -32.0), Vector2(38.0, 0.0)]
const SLAB_SHADE := [Vector2(14.0, -30.0), Vector2(26.0, -32.0), Vector2(38.0, 0.0), Vector2(26.0, 0.0)]
const GLINT_AT := Vector2(-24.0, -26.0)
const GLINT_SIZE := 26.0
## One quick twinkle every so often, not a beacon.
const GLINT_EVERY := Vector2(2.5, 5.0)
const GLINT_SECONDS := 0.35
const SORT_LIFT := 120.0
## The pen's camera is pulled right back to fit the crane.
const SIZE := 1.4

var _time := 0.0
var _next_glint := 1.0
var _glint := 0.0
var _glint_node: Node2D

func _ready() -> void:
	scale = Vector2.ONE * SIZE
	_glint_node = Node2D.new()
	_glint_node.z_index = 5
	_glint_node.position = Vector2(0.0, SORT_LIFT / SIZE)
	_glint_node.draw.connect(_draw_glint)
	add_child(_glint_node)
	_next_glint = randf_range(GLINT_EVERY.x, GLINT_EVERY.y)

func _process(delta: float) -> void:
	_time += delta
	if _time >= _next_glint:
		_glint = GLINT_SECONDS
		_next_glint = _time + randf_range(GLINT_EVERY.x, GLINT_EVERY.y)
	if _glint > 0.0:
		_glint = maxf(_glint - delta, 0.0)
		_glint_node.queue_redraw()

## Found: out on top of the junk, where everyone can see it.
func uncover() -> void:
	z_index = 5

func _draw() -> void:
	draw_set_transform(Vector2(0.0, SORT_LIFT / SIZE))
	draw_colored_polygon(PackedVector2Array(SLAB), GOLD)
	draw_colored_polygon(PackedVector2Array(SLAB_SHADE), GOLD_SHADE)

func _draw_glint() -> void:
	var size := GLINT_SIZE * sin(_glint / GLINT_SECONDS * PI)
	if size < 2.0:
		return
	var thin := size * 0.28
	_glint_node.draw_colored_polygon(PackedVector2Array([
		GLINT_AT + Vector2(0.0, -size), GLINT_AT + Vector2(thin, -thin), GLINT_AT + Vector2(size, 0.0),
		GLINT_AT + Vector2(thin, thin), GLINT_AT + Vector2(0.0, size), GLINT_AT + Vector2(-thin, thin),
		GLINT_AT + Vector2(-size, 0.0), GLINT_AT + Vector2(-thin, -thin),
	]), GLINT)
