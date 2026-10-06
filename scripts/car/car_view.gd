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
## > 0: a car wider than this (before this node's own scale) is shrunk to fit,
## so long bodies aren't cropped. Smaller cars keep their size.
@export var max_width: float = 0.0
## Passed to a horse (or punker) engine's `gait_rate`, so the map car's
## runner doesn't scurry.
@export var horse_gait_rate: float = 1.0
## Whether the accessories make their sounds (the map car), or stay quiet (the
## garage preview).
@export var audible_accessories: bool = false
## The map cars: move the car so this node's origin sits on the ground line under
## the middle of its wheels, the point Main's y-sort reads, so the whole car sorts as one from
## where it stands, the same way every prop does. Off, the car is centred on the origin.
@export var origin_on_ground: bool = false
## Which part category to highlight while dragging: -1 = none, or a
## PartData.Category value. Drawn by _draw() in this node's local space.
var highlight: int = -1
## With an ACCESSORY highlight, the AccessoryPartData.Spot being dragged.
var highlight_spot: int = -1

const _HIGHLIGHT_RADIUS := 40.0
## How far above the car's lowest point art still counts as touching the ground.
const _GROUND_BAND := 6.0
## How deep (on screen, along y) the patch of ground the car stands on is, as a
## share of the whole car's width: a car is deep, even if only its feet touch.
const _FOOTPRINT_DEPTH_SHARE := 0.35
const _FOOTPRINT_DEPTH_MIN := 24.0
const _FOOTPRINT_DEPTH_MAX := 44.0
const _FOOTPRINT_MIN_WIDTH := 16.0
const _BARE_FOOTPRINT := Rect2(-_FOOTPRINT_MIN_WIDTH / 2.0, -_FOOTPRINT_DEPTH_MIN, _FOOTPRINT_MIN_WIDTH, _FOOTPRINT_DEPTH_MIN)

var _fit: Node2D
var _body: CarBody
var _wheels: Array[Node2D] = []
var _engine: Node2D
var _accessories: Array[CarAccessory] = []
var _mounts_local: Array[Vector2] = []
var _engine_mount_raw: Vector2 = Vector2.ZERO
var _engine_mount_local: Vector2 = Vector2.ZERO
var _has_engine_mount: bool = false
## In this node's local space, see `fit_collision()`.
var _footprint: Rect2 = _BARE_FOOTPRINT

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

func set_highlight(category: int, spot: int = -1) -> void:
	if highlight == category and highlight_spot == spot:
		return
	highlight = category
	highlight_spot = spot
	queue_redraw()

func build_from(car: CarModelData) -> void:
	_ensure_fit()
	_clear()
	if car == null or car.body == null or car.body.scene_path.is_empty():
		queue_redraw()
		return

	_body = _instance_visual(car.body) as CarBody
	_fit.add_child(_body)

	var raw_mounts: Array[Marker2D] = _body.get_wheel_mounts()
	var raw_positions: Array[Vector2] = []
	for marker in raw_mounts:
		raw_positions.append(marker.position)

	for i in raw_positions.size():
		var wheel_data: WheelPartData = car.wheels[i] if i < car.wheels.size() else null
		if wheel_data != null and not wheel_data.scene_path.is_empty():
			var wheel := _instance_visual(wheel_data)
			wheel.position = raw_positions[i]
			_fit.add_child(wheel)
			_wheels.append(wheel)

	var engine_mount := _body.get_engine_mount()
	_has_engine_mount = engine_mount != null
	if _has_engine_mount:
		_engine_mount_raw = engine_mount.position

	if car.engine != null and not car.engine.scene_path.is_empty():
		_engine = _instance_visual(car.engine)
		_body.add_child(_engine)
		# Engines are authored with their origin at the mounting base, so
		# snapping to this body's EngineMount seats them on the hood/top/
		# stern/... instead of straddling the body origin.
		_body.place_engine(_engine)
		if _engine is HorseEngine or _engine is PunkerEngine:
			_engine.set(&"gait_rate", horse_gait_rate)

	_accessories = CarAccessory.instantiate_all(car)
	for accessory in _accessories:
		_neutralize_physics(accessory)
	CarAccessory.mount_all(_body, _accessories, _wheels, audible_accessories, false)

	_apply_fit(raw_positions)
	queue_redraw()

## Gives a soft body (the mattress) a squish, for when the car is changed in
## the garage and nothing actually moves to set it wobbling.
func jiggle(amount: float = 120.0) -> void:
	if _body == null:
		return
	for child in _body.get_children():
		if child is SoftBodyWobble:
			child.poke(amount)

## Shapes `collision` (a shape on the body carrying this view) to the patch of
## ground the car stands on: a thin strip spanning whatever reaches the ground —
## wheels, legs, tracks, hooves, or the body itself when it sits lowest.
## Accessories never count. Call again after a facing flip (`scale.x` = -1).
func fit_collision(collision: CollisionShape2D) -> void:
	collision.shape = RoundedRectShape.build(_footprint.size, _footprint.size.y * 0.5)
	mirror_collision(collision)

## Keeps a `fit_collision()` shape under the car after `scale.x` flips it.
func mirror_collision(collision: CollisionShape2D) -> void:
	var center := _footprint.get_center()
	collision.position = Vector2(center.x * signf(scale.x), center.y)

## Wheel mount positions in this node's local space (already fit-adjusted),
## so the garage can drop wheel zones right on top of them.
func get_wheel_mounts() -> Array[Vector2]:
	return _mounts_local.duplicate()

## The current body's lamps. Their global transforms already include the fit
## scale, the facing mirror and the tilt, so a beam can be aimed straight off them.
func get_headlights() -> Array[HeadlightMount]:
	if _body == null:
		return []
	return _body.get_headlight_mounts()

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
	_accessories.clear()
	_mounts_local.clear()
	_has_engine_mount = false
	_engine_mount_raw = Vector2.ZERO
	_engine_mount_local = Vector2.ZERO
	_footprint = _BARE_FOOTPRINT

func _instance_visual(part: PartData) -> Node2D:
	var instance := PartFactory.instantiate(part)
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
	var bounds := PartScale.measure_bounds(_fit, auto_fit_width > 0.0)
	var scale := 1.0
	if auto_fit_width > 0.0 and bounds.size.x > 0.0:
		scale = auto_fit_width / bounds.size.x
	elif max_width > 0.0 and bounds.size.x > max_width:
		scale = max_width / bounds.size.x
	_fit.scale = Vector2(scale, scale)
	_fit.position = -bounds.get_center() * scale
	_footprint = _measure_footprint(bounds.size.x * scale)
	if origin_on_ground:
		# Centred on x too, so turning around mirrors the car in place instead of
		# swinging its footprint into whatever it's parked against.
		_fit.position -= Vector2(_footprint.get_center().x, _footprint.end.y)
		_footprint.position = Vector2(-_footprint.size.x / 2.0, -_footprint.size.y)

	_mounts_local.clear()
	for m in raw_mounts:
		_mounts_local.append(_fit.position + m * scale)
	_engine_mount_local = _fit.position + _engine_mount_raw * scale

## Spans the full width of every part that reaches the ground (each wheel, the
## engine when it's a horse, the body when it sits lowest), not just the few
## pixels where each one touches, so a big wheel is as solid as it looks.
func _measure_footprint(car_width: float) -> Rect2:
	var part_bounds: Array[Rect2] = []
	var ground_parts: Array[Node2D] = [_body]
	ground_parts.append_array(_wheels)
	if _engine != null:
		ground_parts.append(_engine)
	for part in ground_parts:
		var points := PackedVector2Array()
		var to_view := get_global_transform().affine_inverse() * part.get_global_transform()
		_collect_part_art(part, to_view, points)
		if not points.is_empty():
			part_bounds.append(_bounds_of(points))
	if part_bounds.is_empty():
		return _BARE_FOOTPRINT
	var ground_y := -INF
	for bounds in part_bounds:
		ground_y = maxf(ground_y, bounds.end.y)
	var left := INF
	var right := -INF
	for bounds in part_bounds:
		if bounds.end.y >= ground_y - _GROUND_BAND:
			left = minf(left, bounds.position.x)
			right = maxf(right, bounds.end.x)
	var center_x := (left + right) / 2.0
	var width := maxf(right - left, _FOOTPRINT_MIN_WIDTH)
	var depth := clampf(car_width * _FOOTPRINT_DEPTH_SHARE, _FOOTPRINT_DEPTH_MIN, _FOOTPRINT_DEPTH_MAX)
	return Rect2(center_x - width / 2.0, ground_y - depth, width, depth)

## Every Polygon2D vertex of one part, through `xform`, leaving out accessories
## and the engine (a part of its own) when walking the body.
func _collect_part_art(node: Node, xform: Transform2D, points: PackedVector2Array) -> void:
	if node is Polygon2D and (node as Polygon2D).visible:
		for vertex in (node as Polygon2D).polygon:
			points.append(xform * vertex)
	for child in node.get_children():
		if child is CarAccessory or child == _engine or not child is Node2D:
			continue
		_collect_part_art(child, xform * (child as Node2D).get_transform(), points)

static func _bounds_of(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds

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
		PartData.Category.ACCESSORY:
			if highlight_spot == AccessoryPartData.Spot.SKIN:
				_draw_body_glow()
			elif highlight_spot >= 0 and _body != null:
				_draw_ring(_fit.position + _body.get_accessory_mount(highlight_spot) * _fit.scale)

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
