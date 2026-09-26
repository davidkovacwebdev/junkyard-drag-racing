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

const _HIGHLIGHT_RADIUS := 40.0

var _fit: Node2D
var _body: CarBody
var _wheels: Array[Node2D] = []
var _engine: Node2D
var _mounts_local: Array[Vector2] = []
var _engine_mount_raw: Vector2 = Vector2.ZERO
var _engine_mount_local: Vector2 = Vector2.ZERO
var _has_engine_mount: bool = false

func _ready() -> void:
	_ensure_fit()

func _ensure_fit() -> void:
	if _fit == null:
		_fit = Node2D.new()
		_fit.name = "Fit"
		# The drop highlights are this node's own drawing; keep them on top of
		# the car art instead of hidden behind it.
		_fit.show_behind_parent = true
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

	var engine_mount := _body.get_engine_mount()
	_has_engine_mount = engine_mount != null
	if _has_engine_mount:
		_engine_mount_raw = engine_mount.position

	if car.engine != null and not car.engine.scene_path.is_empty():
		_engine = _instance_visual(car.engine.scene_path)
		_body.add_child(_engine)
		# Engines are authored with their origin at the mounting base, so
		# snapping to this body's EngineMount seats them on the hood/top/
		# stern/... instead of straddling the body origin.
		_body.place_engine(_engine)

	_apply_fit(raw_positions)
	queue_redraw()

## Wheel mount positions in this node's local space (already fit-adjusted),
## so the garage can drop wheel zones right on top of them.
func get_wheel_mounts() -> Array[Vector2]:
	return _mounts_local.duplicate()

## Animates every wheel over `distance` world pixels of travel along the car's
## facing: positive moves the car toward its facing (+x) side, negative
## reverses. No physics happens in the map car, so this is what sells the
## motion.
##
## The wheels animate themselves — this just feeds them the movement, looked
## up by name so a wheel scene only has to implement `animate_visual(distance,
## delta)` to bring itself to life (a plain wheel rolls, a paddle swings).
## Nothing here assumes it knows how a given part moves.
##
## The facing flip is a `Visual.scale.x = -1` mirror, which also flips any
## wheel's on-screen motion, so the caller passes velocity already signed for
## facing and every wheel reads as moving the right way from either direction.
func animate_wheels(distance: float, delta: float) -> void:
	for wheel in _wheels:
		if wheel.has_method("animate_visual"):
			wheel.call("animate_visual", distance, delta)

func _clear() -> void:
	for child in _fit.get_children():
		# Detach as well as free: queue_free() leaves the node in the tree
		# until the end of the frame, and _apply_fit() measures these children
		# to size the fit — so leaving the old car in place would measure it.
		_fit.remove_child(child)
		child.queue_free()
	_body = null
	_wheels.clear()
	_engine = null
	_mounts_local.clear()
	_has_engine_mount = false
	_engine_mount_raw = Vector2.ZERO
	_engine_mount_local = Vector2.ZERO

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
	# PartScale.measure_bounds measures a part the same way the wheels measure
	# their own rolling radius, so there's one answer to "how big is this art".
	var bounds := PartScale.measure_bounds(_fit)
	var scale := 1.0
	if auto_fit_width > 0.0 and bounds.size.x > 0.0:
		scale = auto_fit_width / bounds.size.x
	_fit.scale = Vector2(scale, scale)
	_fit.position = -bounds.get_center() * scale

	_mounts_local.clear()
	for m in raw_mounts:
		_mounts_local.append(_fit.position + m * scale)
	_engine_mount_local = _fit.position + _engine_mount_raw * scale

func _draw() -> void:
	match highlight:
		PartData.Category.WHEEL:
			for m in _mounts_local:
				_draw_ring(m)
		PartData.Category.ENGINE:
			if _has_engine_mount:
				_draw_ring(_engine_mount_local)
		PartData.Category.BODY:
			_draw_body_glow()

## Drop-target highlights are flat, pulsing yellow shapes (no outlines, per the
## ui-style skill): an octagon over each mount, a wash over the body.
func _highlight_color(base_alpha: float) -> Color:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var color := UiPalette.ACCENT_YELLOW
	color.a = base_alpha + 0.15 * pulse
	return color

func _draw_ring(center: Vector2) -> void:
	var octagon := PackedVector2Array()
	for k in 8:
		octagon.append(center + Vector2.from_angle(TAU * k / 8.0 + PI / 8.0) * _HIGHLIGHT_RADIUS)
	draw_colored_polygon(octagon, _highlight_color(0.25))

func _draw_body_glow() -> void:
	if _body == null:
		return
	var color := _highlight_color(0.2)
	for child in _body.get_children():
		if child is Polygon2D:
			var poly: Polygon2D = child
			var pts := PackedVector2Array()
			for p in poly.polygon:
				pts.append(_fit.position + (poly.position + p) * _fit.scale)
			if pts.size() > 2:
				draw_colored_polygon(pts, color)
