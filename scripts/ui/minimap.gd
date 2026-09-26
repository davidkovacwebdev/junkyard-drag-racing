class_name Minimap
extends Control
## Round overworld minimap, north-up and centred on the player's car: a steel
## hubcap rim around a flat map disc showing the roads and every
## MinimapMarker landmark. The HOME marker never leaves the map — out of range
## it's pinned to the rim, pointing the way back.
##
## The disc clips its children, so the road layer is drawn once in world
## space and only moved each frame; the icon layer redraws every frame.

@export var world_to_map_scale: float = 0.035
@export var rim_width: float = 11.0
@export var road_width_pixels: float = 3.0
@export var circle_sides: int = 22
@export var jitter_pixels: float = 1.2
@export var jitter_seed: int = 4417

const MAP_COLOR := Color(0.29, 0.35, 0.34)
const MAP_SHADE := Color(0.24, 0.29, 0.28)
const ROAD_COLOR := Color(0.58, 0.62, 0.58)
const HOME_SHADE := Color(0.80, 0.62, 0.08)
const JUNK_COLOR := Color(0.55, 0.28, 0.14)
const JUNK_SHADE := Color(0.45, 0.22, 0.11)
const HOME_ICON_SIZE := 7.0
const LANDMARK_ICON_SIZE := 6.0
const PLAYER_ARROW_SIZE := 7.0
const MOVING_SPEED := 10.0

var _map_disc: Control
var _road_layer: Node2D
var _icon_layer: Node2D
var _player: PlayerCar
var _player_heading: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_disc = Control.new()
	_map_disc.name = "MapDisc"
	_map_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_map_disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_disc.draw.connect(_draw_map_disc)
	add_child(_map_disc)
	_road_layer = Node2D.new()
	_road_layer.name = "Roads"
	_road_layer.scale = Vector2.ONE * world_to_map_scale
	_road_layer.draw.connect(_draw_roads)
	_map_disc.add_child(_road_layer)
	_icon_layer = Node2D.new()
	_icon_layer.name = "Icons"
	_icon_layer.draw.connect(_draw_icons)
	_map_disc.add_child(_icon_layer)
	# The car and its road network finish _ready after this HUD child does.
	_bind_player.call_deferred()

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	_road_layer.queue_redraw()

func _process(_delta: float) -> void:
	if _player == null:
		return
	if _player.velocity.length() > MOVING_SPEED:
		_player_heading = _player.velocity.angle()
	_road_layer.position = _center() - _player.global_position * world_to_map_scale
	_icon_layer.queue_redraw()

func _center() -> Vector2:
	return size * 0.5

func _outer_radius() -> float:
	return minf(size.x, size.y) * 0.5 - 3.0

func _map_radius() -> float:
	return _outer_radius() - rim_width

func _circle_points(center: Vector2, radius: float, jitter: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = jitter_seed
	var points := PackedVector2Array()
	for i in circle_sides:
		var angle := TAU * i / circle_sides
		points.append(center + Vector2.from_angle(angle) * (radius + rng.randf_range(-jitter, jitter)))
	return points

func _arc_points(center: Vector2, inner_radius: float, outer_radius: float,
		from_angle: float, to_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(center + Vector2.from_angle(lerpf(from_angle, to_angle, float(i) / steps)) * outer_radius)
	for i in range(steps, -1, -1):
		points.append(center + Vector2.from_angle(lerpf(from_angle, to_angle, float(i) / steps)) * inner_radius)
	return points

# --- Rim ------------------------------------------------------------------------

func _draw() -> void:
	var center := _center()
	var radius := _outer_radius()
	draw_colored_polygon(_circle_points(center + Vector2(3, 4), radius, jitter_pixels), UiPalette.SHADOW)
	draw_colored_polygon(_circle_points(center, radius, jitter_pixels), UiPalette.STEEL_SHADE)
	draw_colored_polygon(_circle_points(center + Vector2(-2, -2), radius - 2.0, jitter_pixels), UiPalette.STEEL_BASE)
	draw_colored_polygon(_arc_points(center + Vector2(-2, -2), radius - 7.0, radius - 4.0,
			deg_to_rad(195.0), deg_to_rad(250.0), 5), UiPalette.STEEL_LIGHT)
	var rivet_radius := radius - rim_width * 0.5 - 1.0
	for angle_degrees in [45.0, 135.0, 225.0, 315.0]:
		var rivet := center + Vector2.from_angle(deg_to_rad(angle_degrees)) * rivet_radius
		_draw_square(self, rivet, 1.6, UiPalette.STEEL_DARK)

func _draw_map_disc() -> void:
	var center := _center()
	var radius := _map_radius()
	_map_disc.draw_colored_polygon(_circle_points(center, radius, jitter_pixels * 0.5), MAP_SHADE)
	_map_disc.draw_colored_polygon(_circle_points(center + Vector2(1.5, 2), radius - 2.0, 0.0), MAP_COLOR)

# --- Map contents ---------------------------------------------------------------

func _draw_roads() -> void:
	var roads := _player.get_road_network() if _player != null else null
	if roads == null:
		return
	roads.ensure_built()
	var width := road_width_pixels / world_to_map_scale
	for polyline in roads.get_road_polylines():
		if polyline.size() >= 2:
			_road_layer.draw_polyline(roads.global_transform * polyline, ROAD_COLOR, width)

func _draw_icons() -> void:
	if _player == null:
		return
	var center := _center()
	var map_radius := _map_radius()
	var home_position := Vector2.INF
	for marker: MinimapMarker in get_tree().get_nodes_in_group(MinimapMarker.GROUP):
		var offset := (marker.global_position - _player.global_position) * world_to_map_scale
		if marker.kind == MinimapMarker.Kind.HOME:
			home_position = center + offset.limit_length(map_radius - HOME_ICON_SIZE - 2.0)
		elif offset.length() < map_radius + LANDMARK_ICON_SIZE:
			_draw_landmark(marker.kind, center + offset)
	_draw_player_arrow(center)
	if home_position != Vector2.INF:
		_draw_home(home_position)

func _draw_player_arrow(at: Vector2) -> void:
	var forward := Vector2.from_angle(_player_heading)
	var side := forward.orthogonal()
	var tip := at + forward * PLAYER_ARROW_SIZE
	var tail := at - forward * PLAYER_ARROW_SIZE * 0.4
	var left := at - forward * PLAYER_ARROW_SIZE * 0.7 + side * PLAYER_ARROW_SIZE * 0.7
	var right := at - forward * PLAYER_ARROW_SIZE * 0.7 - side * PLAYER_ARROW_SIZE * 0.7
	_icon_layer.draw_colored_polygon(PackedVector2Array([tip, left, tail]), UiPalette.TEXT_LIGHT)
	_icon_layer.draw_colored_polygon(PackedVector2Array([tip, tail, right]), UiPalette.TRIM_OFF_WHITE)

func _draw_home(at: Vector2) -> void:
	var unit := HOME_ICON_SIZE
	var body := PackedVector2Array([
		at + Vector2(-unit, -unit * 0.1), at + Vector2(0, -unit), at + Vector2(unit, -unit * 0.1),
		at + Vector2(unit * 0.8, unit * 0.8), at + Vector2(-unit * 0.8, unit * 0.8),
	])
	var shade := PackedVector2Array([
		at + Vector2(0, -unit), at + Vector2(unit, -unit * 0.1), at + Vector2(unit * 0.8, unit * 0.8), at + Vector2(0, unit * 0.8),
	])
	_icon_layer.draw_colored_polygon(body, UiPalette.ACCENT_YELLOW)
	_icon_layer.draw_colored_polygon(shade, HOME_SHADE)
	_draw_square(_icon_layer, at + Vector2(0, unit * 0.45), unit * 0.3, UiPalette.INK)

func _draw_landmark(kind: MinimapMarker.Kind, at: Vector2) -> void:
	var unit := LANDMARK_ICON_SIZE
	match kind:
		MinimapMarker.Kind.DRAG_STRIP:
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.7, -unit), at + Vector2(-unit * 0.4, -unit),
				at + Vector2(-unit * 0.4, unit), at + Vector2(-unit * 0.7, unit),
			]), UiPalette.POST_GREY)
			for row in 2:
				for column in 2:
					var cell_color := UiPalette.TEXT_LIGHT if (row + column) % 2 == 0 else UiPalette.INK
					var cell_center := at + Vector2(-unit * 0.1 + column * unit * 0.6, -unit * 0.7 + row * unit * 0.6)
					_draw_square(_icon_layer, cell_center, unit * 0.3, cell_color)
		MinimapMarker.Kind.JUNKYARD:
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, unit * 0.6), at + Vector2(-unit * 0.3, -unit * 0.7),
				at + Vector2(unit * 0.4, -unit * 0.4), at + Vector2(unit, unit * 0.6),
			]), JUNK_COLOR)
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(unit * 0.4, -unit * 0.4), at + Vector2(unit, unit * 0.6), at + Vector2(unit * 0.2, unit * 0.6),
			]), JUNK_SHADE)
		MinimapMarker.Kind.RAMP:
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, unit * 0.6), at + Vector2(unit, -unit * 0.6), at + Vector2(unit, unit * 0.6),
			]), UiPalette.CARDBOARD_BASE)
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(unit * 0.6, -unit * 0.36), at + Vector2(unit, -unit * 0.6), at + Vector2(unit, unit * 0.6), at + Vector2(unit * 0.6, unit * 0.6),
			]), UiPalette.CARDBOARD_DARK)

func _draw_square(canvas: CanvasItem, at: Vector2, half_size: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-half_size, -half_size), at + Vector2(half_size, -half_size),
		at + Vector2(half_size, half_size), at + Vector2(-half_size, half_size),
	]), color)
