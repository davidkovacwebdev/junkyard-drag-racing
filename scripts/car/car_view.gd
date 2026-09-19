class_name CarView
extends Node2D
## Builds a physics-free, visual-only car from a CarModelData's parts, so
## the same assembled car can be shown in the garage preview AND as the
## player's world car. Parts are instanced from their real scenes and
## neutralized (frozen, no collision) — they're pure decoration here.
##
## `auto_fit_width` > 0 scales the whole car uniformly to that pixel width
## (the world player is a small fixed-size car); 0 leaves parts at natural
## size (the garage zooms in to browse them). When > 0 the car is also
## centered on this node's origin.

@export var auto_fit_width: float = 0.0
## Which part category to highlight while dragging: -1 = none, or a
## PartData.Category value. Drawn by _draw() in this node's local space.
var highlight: int = -1

const ENGINE_OFFSET := Vector2(0, -38)   # where engine scenes sit on the body
const _HIGHLIGHT_RADIUS := 40.0

var _fit: Node2D
var _body: CarBody
var _wheels: Array[Node2D] = []
var _engine: Node2D
var _mounts_local: Array[Vector2] = []
var _engine_mount_local: Vector2 = Vector2.ZERO

func _ready() -> void:
	_ensure_fit()

func _ensure_fit() -> void:
	if _fit == null:
		_fit = Node2D.new()
		_fit.name = "Fit"
		add_child(_fit)

func _process(_delta: float) -> void:
	if highlight >= 0:
		queue_redraw()

func set_highlight(category: int) -> void:
	if highlight == category:
		return
	highlight = category
	queue_redraw()

func build_from(car: CarModelData) -> void:
	_ensure_fit()
	_clear()
	if car == null or car.body == null or car.body.scene_path.is_empty():
		queue_redraw()
		return

	_body = _instance_visual(car.body.scene_path) as CarBody
	_fit.add_child(_body)

	var raw_mounts: Array[Marker2D] = _body.get_wheel_mounts()
	var raw_positions: Array[Vector2] = []
	for marker in raw_mounts:
		raw_positions.append(marker.position)

	for i in raw_positions.size():
		var wheel_data: WheelPartData = car.wheels[i] if i < car.wheels.size() else null
		if wheel_data != null and not wheel_data.scene_path.is_empty():
			var wheel := _instance_visual(wheel_data.scene_path)
			wheel.position = raw_positions[i]
			_fit.add_child(wheel)
			_wheels.append(wheel)

	if car.engine != null and not car.engine.scene_path.is_empty():
		_engine = _instance_visual(car.engine.scene_path)
		_body.add_child(_engine)

	_apply_fit(raw_positions)
	queue_redraw()

## Wheel mount positions in this node's local space (already fit-adjusted),
## so the garage can drop wheel zones right on top of them.
func get_wheel_mounts() -> Array[Vector2]:
	return _mounts_local.duplicate()

func _clear() -> void:
	for child in _fit.get_children():
		child.queue_free()
	_body = null
	_wheels.clear()
	_engine = null
	_mounts_local.clear()

func _instance_visual(scene_path: String) -> Node2D:
	var instance: Node2D = (load(scene_path) as PackedScene).instantiate()
	_neutralize_physics(instance)
	return instance

func _neutralize_physics(node: Node) -> void:
	if node is RigidBody2D:
		node.freeze = true
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_neutralize_physics(child)

func _apply_fit(raw_mounts: Array[Vector2]) -> void:
	_fit.scale = Vector2.ONE
	_fit.position = Vector2.ZERO
	var points := PackedVector2Array()
	_gather_points(_fit, points)
	var bounds := _points_bounds(points)
	var scale := 1.0
	if auto_fit_width > 0.0 and bounds.size.x > 0.0:
		scale = auto_fit_width / bounds.size.x
	_fit.scale = Vector2(scale, scale)
	_fit.position = -bounds.get_center() * scale

	_mounts_local.clear()
	for m in raw_mounts:
		_mounts_local.append(_fit.position + m * scale)
	_engine_mount_local = _fit.position + ENGINE_OFFSET * scale

func _points_bounds(points: PackedVector2Array) -> Rect2:
	var r := Rect2()
	var has := false
	for p in points:
		if has:
			r = r.expand(p)
		else:
			r = Rect2(p, Vector2.ZERO)
			has = true
	return r

func _gather_points(node: Node, out: PackedVector2Array) -> void:
	_gather_recursive(node, Transform2D.IDENTITY, out)

func _gather_recursive(node: Node, xform: Transform2D, out: PackedVector2Array) -> void:
	if node is Node2D:
		xform = xform * node.get_transform()
	if node is Polygon2D:
		for p in node.polygon:
			out.append(xform * p)
	for child in node.get_children():
		_gather_recursive(child, xform, out)

func _draw() -> void:
	match highlight:
		PartData.Category.WHEEL:
			for m in _mounts_local:
				_draw_ring(m)
		PartData.Category.ENGINE:
			_draw_ring(_engine_mount_local)
		PartData.Category.BODY:
			_draw_body_outline()

func _draw_ring(center: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var fill := Color(1.0, 0.85, 0.2, 0.12 + 0.12 * pulse)
	var outline := Color(1.0, 0.85, 0.2, 0.6 + 0.35 * pulse)
	draw_circle(center, _HIGHLIGHT_RADIUS, fill)
	draw_arc(center, _HIGHLIGHT_RADIUS, 0.0, TAU, 40, outline, 3.0, true)

func _draw_body_outline() -> void:
	if _body == null:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var outline := Color(1.0, 0.85, 0.2, 0.5 + 0.35 * pulse)
	for child in _body.get_children():
		if child is Polygon2D:
			var poly: Polygon2D = child
			var pts := PackedVector2Array()
			for p in poly.polygon:
				pts.append(_fit.position + (poly.position + p) * _fit.scale)
			if pts.size() > 2:
				pts.append(pts[0])
				draw_polyline(pts, outline, 3.0, true)
