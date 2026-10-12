class_name JumpscareFace
extends CanvasLayer
## A huge skull face slammed over the whole screen for a split second, half
## see-through, with a scream: the moment the cemetery's dead wake up
## (CemeteryHaunt). It pops in a little too big, shudders, and is gone.
## Frees itself.
##
## Junk-toy style even when it's scary: the skull, two black eye sockets with
## a red pupil each, a nose hole, and a gaping mouth with three chunky teeth.

const BONE := Color(0.9, 0.88, 0.8, 1)
const HOLE := Color(0.06, 0.05, 0.05, 1)
const EYE := Color(0.95, 0.12, 0.08, 1)
const SECONDS := 0.3
const OPACITY := 0.9
const SHUDDER := 18.0

## Drawn flat into one CanvasGroup, so the whole face fades as one picture
## instead of every overlapping shape showing through the next.
## Extra loudness on top of the usual scream (the Super Horn's haunt).
var boost_db := 0.0
var _group: CanvasGroup
var _face: Node2D
var _screen: Vector2

static func scare(parent: Node, boost_db: float = 0.0) -> void:
	var face := JumpscareFace.new()
	face.boost_db = boost_db
	parent.add_child(face)

func _ready() -> void:
	layer = 50
	_screen = get_viewport().get_visible_rect().size
	_group = CanvasGroup.new()
	_group.self_modulate.a = OPACITY
	_group.position = _screen * 0.5
	_group.scale = Vector2.ONE * 1.25
	add_child(_group)
	_face = Node2D.new()
	_face.draw.connect(_draw_face)
	_group.add_child(_face)
	Sfx.play(&"jumpscare_scream", 12.0 + boost_db, 0.0)
	var tween := create_tween()
	tween.tween_property(_group, "scale", Vector2.ONE, SECONDS * 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(SECONDS * 0.6)
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	_group.position = _screen * 0.5 + Vector2(randf_range(-SHUDDER, SHUDDER), randf_range(-SHUDDER, SHUDDER))

func _draw_face() -> void:
	var c := Vector2.ZERO
	var u := minf(_screen.x, _screen.y) / 100.0
	var at := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	# Skull: a big rounded dome, and the jaw under it.
	_face.draw_colored_polygon(FlatProps.octagon(at.call(0.0, -8.0), 62.0 * u, 52.0 * u), BONE)
	_face.draw_colored_polygon(PackedVector2Array([at.call(-34.0, 26.0), at.call(34.0, 26.0),
			at.call(26.0, 54.0), at.call(-26.0, 54.0)]), BONE)
	# Eye sockets with a red pupil glaring out of each.
	for side: float in [-1.0, 1.0]:
		_face.draw_colored_polygon(FlatProps.octagon(at.call(22.0 * side, -12.0), 16.0 * u, 14.0 * u), HOLE)
		_face.draw_colored_polygon(FlatProps.octagon(at.call(20.0 * side, -10.0), 5.0 * u, 5.0 * u), EYE)
	# Nose hole.
	_face.draw_colored_polygon(PackedVector2Array([at.call(0.0, 6.0), at.call(6.0, 18.0), at.call(-6.0, 18.0)]), HOLE)
	# Screaming mouth and three teeth hanging into it.
	_face.draw_colored_polygon(FlatProps.octagon(at.call(0.0, 38.0), 20.0 * u, 13.0 * u), HOLE)
	for x: float in [-10.0, 0.0, 10.0]:
		_face.draw_rect(Rect2(at.call(x - 3.5, 25.0), Vector2(7.0, 8.0) * u), BONE)
