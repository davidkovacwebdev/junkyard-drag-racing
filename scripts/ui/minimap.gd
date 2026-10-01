class_name Minimap
extends Control
## Round overworld minimap, north-up and centred on the player's car: a plain
## steel rim around a flat map disc showing the roads and every
## MinimapMarker landmark. The HOME marker never leaves the map — out of range
## it's pinned to the rim, pointing the way back.
##
## The disc clips its children, so the road layer is drawn once in world
## space and only moved each frame; the icon layer redraws every frame.
##
## A quest giver (the `quest_giver` group) with a quest available shows as a
## little copy of their own head, pinned to the rim like HOME when they're
## out of range, so the player can always find who has work for them.
##
## Whatever the tracked quest sends the player to (Quests.tracked_target(): a
## place like the Shop, or the giver once it's time to hand in) is lit up: a
## pulsing yellow disc behind its icon, or a yellow backing behind the
## giver's head, and pinned to the rim too.

@export var world_to_map_scale: float = 0.035
@export var rim_width: float = 11.0
@export var road_width_pixels: float = 4.0
@export var circle_sides: int = 22
@export var jitter_pixels: float = 1.2
@export var jitter_seed: int = 4417

const MAP_COLOR := Color(0.29, 0.35, 0.34)
const ROAD_COLOR := Color(0.58, 0.62, 0.58)
const HOME_SHADE := Color(0.80, 0.62, 0.08)
const JUNK_COLOR := Color(0.55, 0.28, 0.14)
const JUNK_SHADE := Color(0.45, 0.22, 0.11)
const BARN_COLOR := Color(0.62, 0.2, 0.16)
const BARN_SHADE := Color(0.5, 0.16, 0.13)
const ANVIL_COLOR := Color(0.26, 0.26, 0.28)
const ANVIL_SHADE := Color(0.2, 0.2, 0.22)
const EMBER_COLOR := Color(0.98, 0.62, 0.12)
const RALLY_HILL := Color(0.45, 0.52, 0.31)
const RALLY_HILL_SHADE := Color(0.38, 0.44, 0.26)
const RALLY_PENNANT := Color(0.85, 0.45, 0.12)
const HOME_ICON_SIZE := 7.0
const LANDMARK_ICON_SIZE := 6.0
const PLAYER_ARROW_SIZE := 7.0
const MOVING_SPEED := 10.0
## Quest-giver heads: how small the character is drawn, which point of the
## character (a head's middle, in character space) sits on the map spot, and
## the dark disc behind it so it reads against the map.
const HEAD_SCALE := 0.17
const HEAD_CENTER_Y := -200.0
const HEAD_BACK_RADIUS := 11.0
const GIVER_GROUP := &"quest_giver"
## The quest-target glow: its size around an icon, and how fast it pulses.
const TARGET_GLOW_RADIUS := 10.0
## HOME's icon is already yellow, so its glow is drawn wider to show as a ring.
const HOME_GLOW_RADIUS := 15.0
const TARGET_PULSE_SPEED := 5.0
const TARGET_GLOW := Color(0.95, 0.75, 0.10, 0.55)

var _map_disc: Control
var _road_layer: Node2D
var _icon_layer: Node2D
var _player: PlayerCar
var _player_heading: float = 0.0
## Quest giver node -> its head on the map.
var _heads: Dictionary = {}

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
	_update_quest_heads()

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

# --- Rim ------------------------------------------------------------------------

func _draw() -> void:
	draw_colored_polygon(_circle_points(_center(), _outer_radius(), jitter_pixels), UiPalette.STEEL_BASE)

func _draw_map_disc() -> void:
	_map_disc.draw_colored_polygon(_circle_points(_center(), _map_radius(), jitter_pixels * 0.5), MAP_COLOR)

# --- Map contents ---------------------------------------------------------------

func _draw_roads() -> void:
	var roads := _player.get_road_network() if _player != null else null
	if roads == null:
		return
	roads.ensure_built()
	var width := road_width_pixels / world_to_map_scale
	for polyline in roads.get_draw_polylines():
		if polyline.size() >= 2:
			_road_layer.draw_polyline(roads.global_transform * polyline, ROAD_COLOR, width)

func _draw_icons() -> void:
	if _player == null:
		return
	var center := _center()
	var map_radius := _map_radius()
	var home_position := Vector2.INF
	var home_is_target := false
	var target := Quests.tracked_target()
	for marker: MinimapMarker in get_tree().get_nodes_in_group(MinimapMarker.GROUP):
		var offset := (marker.global_position - _player.global_position) * world_to_map_scale
		if marker.kind == MinimapMarker.Kind.HOME:
			home_position = center + offset.limit_length(map_radius - HOME_ICON_SIZE - 2.0)
			home_is_target = home_is_target or (not target.is_empty() and marker.place_name() == target)
		elif not target.is_empty() and marker.place_name() == target:
			var at := center + offset.limit_length(map_radius - TARGET_GLOW_RADIUS - 1.0)
			_draw_target_glow(at)
			_draw_landmark(marker.kind, at)
		elif offset.length() < map_radius + LANDMARK_ICON_SIZE:
			_draw_landmark(marker.kind, center + offset)
	_draw_player_arrow(center)
	if home_position != Vector2.INF:
		if home_is_target:
			_draw_target_glow(home_position, HOME_GLOW_RADIUS)
		_draw_home(home_position)

func _draw_target_glow(at: Vector2, radius: float = TARGET_GLOW_RADIUS) -> void:
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.001 * TARGET_PULSE_SPEED)
	var disc := PackedVector2Array()
	for i in 8:
		disc.append(at + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * radius * pulse)
	_icon_layer.draw_colored_polygon(disc, TARGET_GLOW)

func _update_quest_heads() -> void:
	for giver in _heads.keys():
		if not is_instance_valid(giver):
			(_heads[giver] as Node2D).queue_free()
			_heads.erase(giver)
	var center := _center()
	var reach := _map_radius() - HEAD_BACK_RADIUS - 1.0
	var target := Quests.tracked_target()
	for giver in get_tree().get_nodes_in_group(GIVER_GROUP):
		var giver_name := String(giver.get("display_name"))
		var is_target := not target.is_empty() and giver_name == target
		var waiting := is_target or not Quests.available_from(giver_name).is_empty()
		var head: Node2D = _heads.get(giver)
		if head == null:
			if not waiting:
				continue
			head = _make_head(giver.get("character_data") as CharacterData)
			_map_disc.add_child(head)
			_heads[giver] = head
		head.visible = waiting
		(head.get_node("Backing") as Polygon2D).color = UiPalette.ACCENT_YELLOW if is_target else UiPalette.INK
		if waiting:
			var offset := ((giver as Node2D).global_position - _player.global_position) * world_to_map_scale
			head.position = center + offset.limit_length(reach)

## Just the head, hair, eyes and accessory of `character`, shrunk onto a dark
## disc.
func _make_head(character: CharacterData) -> Node2D:
	var root := Node2D.new()
	var backing := Polygon2D.new()
	backing.name = "Backing"
	var disc := PackedVector2Array()
	for i in 8:
		disc.append(Vector2.from_angle(TAU * (i + 0.5) / 8.0) * HEAD_BACK_RADIUS)
	backing.polygon = disc
	backing.color = UiPalette.INK
	root.add_child(backing)
	if character != null:
		var face := CharacterData.new()
		face.head_scene = character.head_scene
		face.hair_scene = character.hair_scene
		face.eyes_scene = character.eyes_scene
		face.accessory_scene = character.accessory_scene
		var rig := CharacterAssembler.assemble(face, root, Vector2(0.0, -HEAD_CENTER_Y * HEAD_SCALE))
		rig.scale = Vector2.ONE * HEAD_SCALE
	return root

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
		MinimapMarker.Kind.FARM:
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.8, unit * 0.7), at + Vector2(-unit * 0.8, -unit * 0.2), at + Vector2(0, -unit * 0.9),
				at + Vector2(unit * 0.8, -unit * 0.2), at + Vector2(unit * 0.8, unit * 0.7),
			]), BARN_COLOR)
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0, -unit * 0.9), at + Vector2(unit * 0.8, -unit * 0.2), at + Vector2(unit * 0.8, unit * 0.7), at + Vector2(unit * 0.4, unit * 0.7),
			]), BARN_SHADE)
			_draw_square(_icon_layer, at + Vector2(0, unit * 0.35), unit * 0.3, UiPalette.TRIM_OFF_WHITE)
		MinimapMarker.Kind.FORGE:
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, -unit * 0.5), at + Vector2(unit * 0.8, -unit * 0.5), at + Vector2(unit * 0.8, -unit * 0.1),
				at + Vector2(unit * 0.3, 0), at + Vector2(unit * 0.5, unit * 0.7), at + Vector2(-unit * 0.5, unit * 0.7),
				at + Vector2(-unit * 0.3, 0), at + Vector2(-unit * 0.5, -unit * 0.2),
			]), ANVIL_COLOR)
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(unit * 0.3, 0), at + Vector2(unit * 0.5, unit * 0.7), at + Vector2(unit * 0.15, unit * 0.7), at + Vector2(0, 0),
			]), ANVIL_SHADE)
			_draw_square(_icon_layer, at + Vector2(unit * 0.1, -unit * 0.85), unit * 0.2, EMBER_COLOR)
		MinimapMarker.Kind.SHOP:
			# A price tag: pointed end left, string hole in it.
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, 0), at + Vector2(-unit * 0.4, -unit * 0.7), at + Vector2(unit, -unit * 0.7),
				at + Vector2(unit, unit * 0.7), at + Vector2(-unit * 0.4, unit * 0.7),
			]), UiPalette.CARDBOARD_LIGHT)
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(unit * 0.6, -unit * 0.7), at + Vector2(unit, -unit * 0.7),
				at + Vector2(unit, unit * 0.7), at + Vector2(unit * 0.6, unit * 0.7),
			]), UiPalette.CARDBOARD_DARK)
			_draw_square(_icon_layer, at + Vector2(-unit * 0.4, 0), unit * 0.18, UiPalette.VOID)
		MinimapMarker.Kind.RALLY:
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, unit * 0.7), at + Vector2(-unit * 0.1, -unit * 0.3), at + Vector2(unit, unit * 0.7),
			]), RALLY_HILL)
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.1, -unit * 0.3), at + Vector2(unit, unit * 0.7), at + Vector2(unit * 0.4, unit * 0.7),
			]), RALLY_HILL_SHADE)
			_icon_layer.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.2, -unit * 0.3), at + Vector2(-unit * 0.2, -unit), at + Vector2(unit * 0.5, -unit * 0.75),
			]), RALLY_PENNANT)

func _draw_square(canvas: CanvasItem, at: Vector2, half_size: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-half_size, -half_size), at + Vector2(half_size, -half_size),
		at + Vector2(half_size, half_size), at + Vector2(-half_size, half_size),
	]), color)
