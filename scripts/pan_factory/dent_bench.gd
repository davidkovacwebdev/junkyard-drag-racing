class_name DentBench
extends Control
## The pan factory's workbench: the part being bent, drawn big from its own
## polygons, over a faint yellow wash of its collision outline so you can see
## the shape it'll actually bump with. A yellow blob under the mouse shows the
## picked hammer's reach; clicking swings it (`struck`, in the part's space).
##
## The hammer swings in from one side of the screen (`swing_side`: from above
## at first, `turn_hammer` moves it a quarter turn round), handle off to the
## right so the head lands a little leftward; `mirrored` puts the handle on the
## other side and the blow lands the other way. Turning the part (`turn`, or the
## mouse wheel over the bench) and the hammer picks which side of it gets dented
## and which way.

signal struck(point: Vector2, direction: Vector2)
## The mouse wheel turned the part.
signal turned

## How far one notch of the mouse wheel turns the part.
const WHEEL_TURN_DEGREES := 15.0
const TURN_TIME := 0.15
## Which way the hammer pushes on screen for each `swing_side` (from above,
## from the left, from below, from the right), and how far round the hammer
## art is turned to come in from there.
const SWING_PUSH: Array[Vector2] = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
const SWING_ANGLE: Array[float] = [0.0, -PI / 2.0, PI, PI / 2.0]
## How far off straight the blow lands, toward the side away from the handle
## (the head's still travelling round its arc when it hits).
const SWING_TILT := deg_to_rad(30.0)

const FIT := 0.78
const MAX_ZOOM := 4.0
const COLLISION_WASH := Color(0.95, 0.75, 0.10, 0.22)
const REACH_WASH := Color(0.95, 0.75, 0.10, 0.3)
const HANDLE := Color(0.55, 0.40, 0.28)
const SWING_TIME := 0.16
## Hammer head size on the bench, in screen pixels, per hammer.
const HEAD_SIZE := {
	PartDent.Hammer.TACK: Vector2(26, 14),
	PartDent.Hammer.CLAW: Vector2(40, 20),
	PartDent.Hammer.SLEDGE: Vector2(66, 34),
}

var hammer: PartDent.Hammer = PartDent.Hammer.CLAW:
	set(value):
		hammer = value
		queue_redraw()

## Which side the hammer comes in from, an index into SWING_PUSH.
var swing_side := 0:
	set(value):
		swing_side = posmod(value, SWING_PUSH.size())
		queue_redraw()

## The handle's on the left instead, and the blow lands the other way.
var mirrored := false:
	set(value):
		mirrored = value
		queue_redraw()

var _part: PartData
var _pieces: Array[PartForge.Piece] = []
var _collision := PackedVector2Array()
var _art_diagonal := 0.0
## Part space to bench space.
var _xform := Transform2D.IDENTITY
var _mouse := Vector2.ZERO
var _hovering := false
## 1 with the hammer up, 0 the moment it lands.
var _swing := 1.0
var _swing_at := Vector2.ZERO
var _shake := Vector2.ZERO
## Where the part is turning to, and where it's got to (radians).
var _target_angle := 0.0
var _angle := 0.0:
	set(value):
		_angle = value
		_fit()
var _turn_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_fit)
	mouse_entered.connect(func() -> void: _hovering = true)
	mouse_exited.connect(func() -> void:
		_hovering = false
		queue_redraw())

func part() -> PartData:
	return _part

## Puts `part` on the bench (null clears it), or re-reads it after a dent.
func set_part(part: PartData) -> void:
	_pieces.clear()
	_collision = PackedVector2Array()
	_art_diagonal = 0.0
	if part != _part:
		_stop_turning()
	_part = part
	var root := PartFactory.instantiate(part)
	if root != null:
		_pieces = PartForge.harvest(root, root)
		_art_diagonal = PartDent.art_size(root)
		for child in root.get_children():
			if child is CollisionPolygon2D:
				_collision = (child as CollisionPolygon2D).polygon
				break
		root.free()
	_fit()

## Turns the part on the bench by `degrees` (clockwise).
func turn(degrees: float) -> void:
	if _part == null:
		return
	_target_angle += deg_to_rad(degrees)
	if _turn_tween != null:
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_property(self, "_angle", _target_angle, TURN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Moves the hammer a quarter turn round to the next side.
func turn_hammer() -> void:
	swing_side += 1

## Swaps the handle to the other side.
func mirror_hammer() -> void:
	mirrored = not mirrored

## Which way the blow pushes, on screen.
func screen_push() -> Vector2:
	return SWING_PUSH[swing_side].rotated(-SWING_TILT if mirrored else SWING_TILT)

func _stop_turning() -> void:
	if _turn_tween != null:
		_turn_tween.kill()
	_target_angle = 0.0
	_angle = 0.0

## The hammer comes down on `point` (part space) and the bench jolts.
func swing(point: Vector2) -> void:
	_swing_at = _xform * point
	_swing = 1.0
	var tween := create_tween()
	tween.tween_property(self, "_swing", 0.0, SWING_TIME * 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(_jolt)
	tween.tween_property(self, "_swing", 1.0, SWING_TIME).set_delay(0.08)
	tween.tween_callback(func() -> void: _swing_at = Vector2.ZERO)

func _jolt() -> void:
	var size_kick: float = HEAD_SIZE[hammer].x / 6.0
	var tween := create_tween()
	var kick := (screen_push() + screen_push().orthogonal() * randf_range(-0.3, 0.3)) * size_kick
	tween.tween_property(self, "_shake", kick, 0.03)
	tween.tween_property(self, "_shake", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _process(_delta: float) -> void:
	if _swing_at != Vector2.ZERO or _shake != Vector2.ZERO or _hovering:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
	elif event is InputEventMouseButton and event.pressed and _part != null:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				accept_event()
				var push := _xform.affine_inverse().basis_xform(screen_push()).normalized()
				struck.emit(_xform.affine_inverse() * event.position, push)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				accept_event()
				turn(WHEEL_TURN_DEGREES * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0))
				turned.emit()

func _fit() -> void:
	var points := PackedVector2Array(_collision)
	for piece in _pieces:
		points.append_array(piece.points)
	if points.is_empty():
		queue_redraw()
		return
	var turned_by := Transform2D(_angle, Vector2.ZERO)
	var bounds := PartForge.bounds_of(turned_by * points)
	var zoom := minf(MAX_ZOOM, minf(size.x * FIT / maxf(bounds.size.x, 1.0), size.y * FIT / maxf(bounds.size.y, 1.0)))
	_xform = Transform2D(0.0, Vector2.ONE * zoom, 0.0, size / 2.0 - bounds.get_center() * zoom) * turned_by
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.VOID)
	draw_rect(Rect2(0.0, size.y - 14.0, size.x, 14.0), UiPalette.INK)
	if _part == null:
		return
	draw_set_transform(_shake)
	if PolygonMorph.is_drawable(_collision):
		draw_colored_polygon(_xform * _collision, COLLISION_WASH)
	for piece in _pieces:
		var points := _xform * piece.points
		if PolygonMorph.is_drawable(points):
			draw_colored_polygon(points, piece.color)
	draw_set_transform(Vector2.ZERO)
	if _hovering and _swing_at == Vector2.ZERO:
		var reach := PartDent.reach_for(_art_diagonal, hammer) * _xform.get_scale().x
		draw_colored_polygon(FlatProps.octagon(_mouse, reach, reach), REACH_WASH)
	_draw_hammer()

## The hammer from the side: a handle running off to the right and the head
## across its end, face down on the spot it lands. It pivots on the hand end,
## raised while idle and coming down as `_swing` falls to 0. The whole thing
## is turned to come in from `swing_side`, and flipped when `mirrored`.
func _draw_hammer() -> void:
	if _swing_at == Vector2.ZERO and not _hovering:
		return
	var at := _swing_at if _swing_at != Vector2.ZERO else _mouse
	var lift := _swing if _swing_at != Vector2.ZERO else 1.0
	var head: Vector2 = HEAD_SIZE[hammer]
	var hand := Vector2(head.x * 2.2, -head.x / 2.0)
	var flip := Transform2D(0.0, Vector2(-1.0 if mirrored else 1.0, 1.0), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D(SWING_ANGLE[swing_side], at) * flip * Transform2D(0.9 * lift, hand))
	draw_colored_polygon(FlatProps.sliver(Vector2(0.0, -head.x / 2.0) - hand, Vector2.ZERO,
			maxf(6.0, head.y * 0.45)), HANDLE)
	draw_rect(Rect2(Vector2(-head.y / 2.0, -head.x) - hand, Vector2(head.y, head.x)), UiPalette.STEEL_BASE)
	draw_rect(Rect2(Vector2(head.y * 0.1, -head.x) - hand, Vector2(head.y * 0.4, head.x)), UiPalette.STEEL_SHADE)
	draw_set_transform(Vector2.ZERO)
