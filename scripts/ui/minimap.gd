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

const MOVING_SPEED := 10.0
## Quest-giver heads: how small the character is drawn, which point of the
## character (a head's middle, in character space) sits on the map spot, and
## the dark disc behind it so it reads against the map.
const HEAD_SCALE := 0.17
const HEAD_CENTER_Y := -200.0
const HEAD_BACK_RADIUS := 11.0
const GIVER_GROUP := &"quest_giver"

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
	_map_disc.draw_colored_polygon(_circle_points(_center(), _map_radius(), jitter_pixels * 0.5), MapIcons.MAP_COLOR)

# --- Map contents ---------------------------------------------------------------

func _draw_roads() -> void:
	var roads := _player.get_road_network() if _player != null else null
	if roads == null:
		return
	roads.ensure_built()
	var width := road_width_pixels / world_to_map_scale
	for polyline in roads.get_draw_polylines():
		if polyline.size() >= 2:
			_road_layer.draw_polyline(roads.global_transform * polyline, MapIcons.ROAD_COLOR, width)

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
			home_position = center + offset.limit_length(map_radius - MapIcons.HOME_ICON_SIZE - 2.0)
			home_is_target = home_is_target or (not target.is_empty() and MapIcons.marker_name(marker) == target)
		elif not target.is_empty() and MapIcons.marker_name(marker) == target:
			var at := center + offset.limit_length(map_radius - MapIcons.TARGET_GLOW_RADIUS - 1.0)
			MapIcons.draw_target_glow(_icon_layer, at)
			MapIcons.draw_landmark(_icon_layer, marker.kind, at)
		elif offset.length() < map_radius + MapIcons.LANDMARK_ICON_SIZE:
			MapIcons.draw_landmark(_icon_layer, marker.kind, center + offset)
	MapIcons.draw_player_arrow(_icon_layer, center, _player_heading)
	if home_position != Vector2.INF:
		if home_is_target:
			MapIcons.draw_target_glow(_icon_layer, home_position, MapIcons.HOME_GLOW_RADIUS)
		MapIcons.draw_home(_icon_layer, home_position)

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
