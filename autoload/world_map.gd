extends CanvasLayer
## The full map (autoload `WorldMap`): M unfolds the whole overworld on a
## board, like the GPS minimap but showing everything at once: every road,
## the land, every road, every landmark (its name shows on hover), HOME, the quest target
## and the player. Needs the Map item from the shop; without it M just plays
## `denied`. The game keeps running underneath so you can drive with it open;
## the board is slightly see-through. M or Esc folds it away, and anything that
## pauses the game (journal, pause menu, a dialog) or leaves the world folds
## it too.

const LAYER := 46
const WORLD_SCENE := "res://scenes/world/main.tscn"
const MAP_ITEM := &"map"
const BOARD_SIZE := Vector2(900, 540)
const MAP_MARGIN := Vector2(30, 40)
const FIT_PADDING := 40.0
const ROAD_WIDTH_PIXELS := 5.0
const ICON_SCALE := 2.0
const LABEL_FONT_SIZE := 16
const LABEL_GAP := 18.0
## How close (in map pixels) the mouse must be to an icon to show its name.
const HOVER_RADIUS := 18.0
const BOARD_ALPHA := 0.82
const LAND_COLOR := Color(0.40, 0.43, 0.32)

var _open: bool = false
var _panel: Control
var _map_area: Control
var _land_layer: Node2D
var _road_layer: Node2D
var _icon_layer: Node2D
var _player: PlayerCar
var _terrain: TerrainNetwork
var _world_to_map := Transform2D.IDENTITY
var _hovered_marker: MinimapMarker

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()

func is_open() -> bool:
	return _open

func open() -> void:
	if _open or not _can_open():
		return
	if not Inventory.has_item(MAP_ITEM):
		Sfx.play(&"denied")
		return
	_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	if _player == null:
		return
	_terrain = _find_terrain()
	_open = true
	_panel.visible = true
	_fit_to_world.call_deferred()
	_pop(_panel.get_node("Board"))
	Sfx.play(&"journal_flip", -6.0, 0.05)

func close() -> void:
	if not _open:
		return
	_open = false
	_hovered_marker = null
	_panel.visible = false
	Sfx.play(&"journal_flip", -9.0, 0.05).pitch_scale *= 0.85

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.ctrl_pressed or event.shift_pressed or event.alt_pressed:
		return
	var key: Key = event.physical_keycode
	if _open and (key == KEY_M or key == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
	elif not _open and key == KEY_M and _can_open():
		open()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not _open:
		return
	if not _can_open() or not is_instance_valid(_player):
		close()
		return
	_icon_layer.queue_redraw()

func _can_open() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == WORLD_SCENE \
			and Journal.hud_allowed() and not get_tree().paused

func _find_terrain() -> TerrainNetwork:
	for node in get_tree().current_scene.find_children("*", "Node2D", true, false):
		if node is TerrainNetwork:
			return node
	return null

# --- Fitting the world onto the board ---------------------------------------------

func _fit_to_world() -> void:
	var bounds := Rect2(_player.global_position, Vector2.ZERO)
	var roads := _player.get_road_network()
	if roads != null:
		roads.ensure_built()
		for polyline in roads.get_draw_polylines():
			for point in roads.global_transform * polyline:
				bounds = bounds.expand(point)
	for marker: MinimapMarker in get_tree().get_nodes_in_group(MinimapMarker.GROUP):
		bounds = bounds.expand(marker.global_position)
	if _terrain != null:
		_terrain.ensure_built()
		for coastline in _terrain.get_island_polygons():
			for point in _terrain.global_transform * coastline:
				bounds = bounds.expand(point)
	var area := _map_area.size - Vector2.ONE * FIT_PADDING * 2.0
	var scale := minf(area.x / maxf(bounds.size.x, 1.0), area.y / maxf(bounds.size.y, 1.0))
	var offset := _map_area.size * 0.5 - bounds.get_center() * scale
	_world_to_map = Transform2D(0.0, Vector2.ONE * scale, 0.0, offset)
	_land_layer.transform = _world_to_map
	_land_layer.queue_redraw()
	_road_layer.transform = _world_to_map
	_road_layer.queue_redraw()
	_icon_layer.queue_redraw()

func _to_map(world_position: Vector2) -> Vector2:
	return _world_to_map * world_position

func _draw_map_area() -> void:
	_map_area.draw_rect(Rect2(Vector2.ZERO, _map_area.size), MapIcons.MAP_COLOR)

func _draw_land() -> void:
	if _terrain == null:
		return
	for coastline in _terrain.get_island_polygons():
		_land_layer.draw_colored_polygon(_terrain.global_transform * coastline, LAND_COLOR)

func _draw_roads() -> void:
	var roads := _player.get_road_network() if _player != null else null
	if roads == null:
		return
	var width := ROAD_WIDTH_PIXELS / maxf(_world_to_map.get_scale().x, 0.0001)
	for polyline in roads.get_draw_polylines():
		if polyline.size() >= 2:
			_road_layer.draw_polyline(roads.global_transform * polyline, MapIcons.ROAD_COLOR, width)

func _draw_icons() -> void:
	if not _open or _player == null:
		return
	var target := Quests.tracked_target()
	_update_hovered_marker()
	for marker: MinimapMarker in get_tree().get_nodes_in_group(MinimapMarker.GROUP):
		var at := _to_map(marker.global_position)
		var place_name := MapIcons.marker_name(marker)
		_icon_layer.draw_set_transform(at, 0.0, Vector2.ONE * ICON_SCALE)
		if not target.is_empty() and place_name == target:
			var glow_radius := MapIcons.HOME_GLOW_RADIUS if marker.kind == MinimapMarker.Kind.HOME else MapIcons.TARGET_GLOW_RADIUS
			MapIcons.draw_target_glow(_icon_layer, Vector2.ZERO, glow_radius)
		if marker.kind == MinimapMarker.Kind.HOME:
			MapIcons.draw_home(_icon_layer, Vector2.ZERO)
		else:
			MapIcons.draw_landmark(_icon_layer, marker.kind, Vector2.ZERO)
		_icon_layer.draw_set_transform(Vector2.ZERO)
	var heading := _player.velocity.angle() if _player.velocity.length() > 1.0 else -PI * 0.5
	_icon_layer.draw_set_transform(_to_map(_player.global_position), 0.0, Vector2.ONE * ICON_SCALE)
	MapIcons.draw_player_arrow(_icon_layer, Vector2.ZERO, heading)
	_icon_layer.draw_set_transform(Vector2.ZERO)
	if _hovered_marker != null:
		_draw_marker_name(_hovered_marker)

func _update_hovered_marker() -> void:
	var mouse := _icon_layer.get_local_mouse_position()
	var closest: MinimapMarker = null
	var closest_distance := HOVER_RADIUS
	if Rect2(Vector2.ZERO, _map_area.size).has_point(mouse):
		for marker: MinimapMarker in get_tree().get_nodes_in_group(MinimapMarker.GROUP):
			var distance := mouse.distance_to(_to_map(marker.global_position))
			if distance < closest_distance:
				closest = marker
				closest_distance = distance
	if closest != null and closest != _hovered_marker:
		Sfx.play(&"ui_hover", -14.0)
	_hovered_marker = closest

func _draw_marker_name(marker: MinimapMarker) -> void:
	var label := "Home" if marker.kind == MinimapMarker.Kind.HOME else MapIcons.marker_name(marker)
	if label.is_empty():
		return
	var font := _map_area.get_theme_font(&"font", &"Label")
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var at := _to_map(marker.global_position)
	_icon_layer.draw_string(font, at + Vector2(-label_width * 0.5, LABEL_GAP + LABEL_FONT_SIZE),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, UiPalette.TEXT_LIGHT)

# --- Board ----------------------------------------------------------------------------

func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = BOARD_ALPHA
	_panel.visible = false
	add_child(_panel)

	var board := _make_board(UiPalette.CARDBOARD_BASE, UiPalette.CARDBOARD_SHADE, UiPalette.CARDBOARD_DARK, 1.0, 151, true)
	board.name = "Board"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.set_anchors_preset(Control.PRESET_CENTER)
	board.offset_left = -BOARD_SIZE.x * 0.5
	board.offset_right = BOARD_SIZE.x * 0.5
	board.offset_top = -BOARD_SIZE.y * 0.5 + 20.0
	board.offset_bottom = BOARD_SIZE.y * 0.5 + 20.0
	_panel.add_child(board)

	var title_plate := _make_board(UiPalette.SURFACE_BASE, UiPalette.SURFACE_SHADE, UiPalette.SURFACE_DARK, -1.5, 157, false)
	title_plate.position = Vector2(BOARD_SIZE.x * 0.5 - 110.0, -38.0)
	title_plate.size = Vector2(220.0, 60.0)
	board.add_child(title_plate)
	var title := _make_label("MAP", 32, UiPalette.TEXT_BROWN)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_plate.add_child(title)

	_map_area = Control.new()
	_map_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_area.offset_left = MAP_MARGIN.x
	_map_area.offset_top = MAP_MARGIN.y
	_map_area.offset_right = -MAP_MARGIN.x
	_map_area.offset_bottom = -MAP_MARGIN.y
	_map_area.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_map_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_area.draw.connect(_draw_map_area)
	board.add_child(_map_area)

	_land_layer = Node2D.new()
	_land_layer.draw.connect(_draw_land)
	_map_area.add_child(_land_layer)
	_road_layer = Node2D.new()
	_road_layer.draw.connect(_draw_roads)
	_map_area.add_child(_road_layer)
	_icon_layer = Node2D.new()
	_icon_layer.draw.connect(_draw_icons)
	_map_area.add_child(_icon_layer)

	var hint := _make_label("M / Esc  close", 16, UiPalette.SURFACE_DARK)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -200.0
	hint.offset_top = -36.0
	hint.offset_right = -24.0
	hint.offset_bottom = -12.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board.add_child(hint)

func _make_board(body: Color, shade: Color, skirt: Color, tilt: float, seed: int, nails: bool) -> ScrapPanel:
	var board := ScrapPanel.new()
	board.body_color = body
	board.shade_color = shade
	board.skirt_color = skirt
	board.tilt_degrees = tilt
	board.jitter_seed = seed
	board.nails = nails
	return board

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## A quick squash-and-stretch as the board lands.
func _pop(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.9, 1.08)
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.45)
