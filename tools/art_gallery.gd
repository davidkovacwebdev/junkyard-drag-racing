extends Node2D
## Renders art sheets to PNG so the art can be reviewed side by side:
##   godot res://tools/art_gallery.tscn -- <out_dir> [parts|world|race|ramp|venues|screens|all]
## Parts go in a labelled grid; world set pieces get one shot each.

const CELL := Vector2(260, 220)
const COLUMNS := 6
const PART_FIT := Vector2(220, 160)
const BACKGROUND := Color(0.62, 0.58, 0.5)

const WORLD_SHOTS := [
	{"name": "farm", "scene": "res://scenes/world/farm.tscn", "zoom": 0.9},
	{"name": "forge", "scene": "res://scenes/world/scrap_forge.tscn", "zoom": 1.1},
	{"name": "drag_strip", "scene": "res://scenes/world/drag_strip.tscn", "zoom": 0.45},
	{"name": "rally_stage", "scene": "res://scenes/world/rally_stage.tscn", "zoom": 0.45},
	{"name": "hill_climb_site", "scene": "res://scenes/world/hill_climb_site.tscn", "zoom": 0.45},
	{"name": "derby_pit", "scene": "res://scenes/world/derby_pit.tscn", "zoom": 0.5},
	{"name": "fishing_port", "scene": "res://scenes/world/fishing_port.tscn", "zoom": 0.8},
	{"name": "lighthouse_point", "scene": "res://scenes/world/lighthouse_point.tscn", "zoom": 1.0},
	{"name": "oil_field", "scene": "res://scenes/world/oil_field.tscn", "zoom": 0.9},
	{"name": "crop_fields", "scene": "res://scenes/world/crop_fields.tscn", "zoom": 0.8},
	{"name": "graveyard", "scene": "res://scenes/world/graveyard.tscn", "zoom": 0.9},
	{"name": "water_tower", "scene": "res://scenes/world/water_tower.tscn", "zoom": 1.0},
	{"name": "satellite_array", "scene": "res://scenes/world/satellite_array.tscn", "zoom": 0.9},
	{"name": "crashed_helicopter", "scene": "res://scenes/world/crashed_helicopter.tscn", "zoom": 1.1},
	{"name": "shipwreck", "scene": "res://scenes/world/shipwreck.tscn", "zoom": 1.0},
	{"name": "oil_rig", "scene": "res://scenes/world/oil_rig.tscn", "zoom": 1.0},
	{"name": "lonely_island", "scene": "res://scenes/world/lonely_island.tscn", "zoom": 1.1},
]

const PROP_ROW := [
	"res://scenes/world/registration_booth.tscn",
	"res://scenes/world/ramp_event.tscn",
	"res://scenes/world/garbage_truck/garbage_truck.tscn",
	"res://scenes/world/trash_container.tscn",
	"res://scenes/world/trash_bin.tscn",
	"res://scenes/world/scrap_pickup.tscn",
	"res://scenes/world/part_pickup.tscn",
]

const SCREEN_SHOTS := [
	["main_menu", "res://scenes/menu/main_menu.tscn"],
	["garage", "res://scenes/garage/garage.tscn"],
	["junkyard", "res://scenes/junkyard/junkyard.tscn"],
	["world", "res://scenes/world/main.tscn"],
	["crane_pen", "res://scenes/junkyard/crane_pen.tscn"],
	["settings", "res://scenes/menu/settings_screen.tscn"],
	["credits", "res://scenes/menu/credits_screen.tscn"],
	["save_slots", "res://scenes/menu/save_slots_screen.tscn"],
]

## Each race venue's finish end, where the cars pile into the wall.
const END_WALL_SHOTS := [
	["end_wall_drag", "res://scenes/race/race_drag_strip.tscn"],
	["end_wall_rally", "res://scenes/race/race_rally.tscn"],
	["end_wall_ramp", "res://scenes/race/race_ramp.tscn"],
	["end_wall_hill_climb", "res://scenes/race/race_hill_climb.tscn"],
]
## Races left running for a few seconds, the camera doing its own thing.
const RACE_SHOTS := [
	["hill_climb_race", "res://scenes/race/race_hill_climb.tscn", 22.0],
	["derby_race", "res://scenes/race/race_derby.tscn", 6.0],
]

var _out_dir: String
var _mode: String = "all"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveSystem.process_mode = Node.PROCESS_MODE_DISABLED
	var args := OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	if args.size() > 1:
		_mode = args[1]
	RenderingServer.set_default_clear_color(BACKGROUND)
	ScrapCursor.visible = false
	await get_tree().process_frame
	if _mode in ["parts", "all"]:
		await _shoot_parts()
	if _mode in ["race", "all"]:
		await _shoot_screen("race", "res://scenes/race/race_drag_strip.tscn")
		await _shoot_screen("race_rally", "res://scenes/race/race_rally.tscn")
	if _mode in ["ramp", "all"]:
		await _shoot_ramp_run()
	if _mode in ["venues", "all"]:
		await _shoot_screen("drag_strip_menu", "res://scenes/race/drag_strip_menu.tscn")
		for venue in END_WALL_SHOTS:
			await _shoot_end_wall(venue[0], venue[1])
		for shot in RACE_SHOTS:
			await _shoot_race(shot[0], shot[1], shot[2])
	if _mode in ["screens", "all"]:
		for shot in SCREEN_SHOTS:
			await _shoot_screen(shot[0], shot[1])
	if _mode in ["world", "all"]:
		for shot in WORLD_SHOTS:
			await _shoot_scene(shot["name"], load(shot["scene"]), shot["zoom"])
		await _shoot_houses_and_trees()
		await _shoot_row("props", PROP_ROW, 0.8)
		await _shoot_trash()
	get_tree().quit()

func _shoot_parts() -> void:
	var groups := {"bodies": PartDatabase.bodies, "wheels": PartDatabase.wheels, "engines": PartDatabase.engines,
			"accessories": PartDatabase.accessories}
	for group_name in groups:
		var parts: Array = groups[group_name]
		var holder := _frozen_holder()
		var sheet := Node2D.new()
		holder.add_child(sheet)
		for i in parts.size():
			var part: PartData = parts[i]
			var cell_origin := Vector2(i % COLUMNS, i / COLUMNS) * CELL
			var instance: Node2D = load(part.scene_path).instantiate()
			sheet.add_child(instance)
			var bounds := _polygon_bounds(instance)
			var fit := minf(PART_FIT.x / maxf(bounds.size.x, 1.0), PART_FIT.y / maxf(bounds.size.y, 1.0))
			instance.scale = Vector2.ONE * minf(fit, 2.0)
			instance.position = cell_origin + Vector2(CELL.x * 0.5, 95) - bounds.get_center() * instance.scale
			var label := Label.new()
			label.text = part.display_name
			label.position = cell_origin + Vector2(8, CELL.y - 30)
			label.add_theme_color_override("font_color", Color(0.15, 0.14, 0.13))
			sheet.add_child(label)
		var rows := ceili(parts.size() / float(COLUMNS))
		await _capture(holder, Vector2(COLUMNS * CELL.x, rows * CELL.y), "parts_" + group_name)
	await _shoot_fitted_accessories()

## Every body wearing a different mix of accessories (one per spot, a skin on
## every other one), to check where each body's spots land.
func _shoot_fitted_accessories() -> void:
	var by_spot := {}
	for accessory in PartDatabase.accessories:
		if not by_spot.has(accessory.spot):
			by_spot[accessory.spot] = []
		by_spot[accessory.spot].append(accessory)
	var holder := _frozen_holder()
	var bodies := PartDatabase.bodies
	for i in bodies.size():
		var car := CarModelData.new()
		car.body = bodies[i].duplicate()
		car.engine = PartDatabase.engines[i % PartDatabase.engines.size()].duplicate()
		for mount in PartDatabase.wheel_mount_count(car.body):
			car.wheels.append(PartDatabase.wheels[0].duplicate())
		for spot in by_spot:
			var options: Array = by_spot[spot]
			if spot == AccessoryPartData.Spot.SKIN and i % 2 != 0:
				continue
			car.accessories.append((options[(i / 2 if spot == AccessoryPartData.Spot.SKIN else i) % options.size()] as AccessoryPartData).duplicate())
		var view := CarView.new()
		view.max_width = PART_FIT.x
		holder.add_child(view)
		view.build_from(car)
		var cell_origin := Vector2(i % COLUMNS, i / COLUMNS) * CELL
		view.position = cell_origin + Vector2(CELL.x * 0.5, 105)
		var label := Label.new()
		label.text = car.body.display_name
		label.position = cell_origin + Vector2(8, CELL.y - 30)
		label.add_theme_color_override("font_color", Color(0.15, 0.14, 0.13))
		holder.add_child(label)
	var rows := ceili(bodies.size() / float(COLUMNS))
	await _capture(holder, Vector2(COLUMNS * CELL.x, rows * CELL.y), "parts_fitted_accessories")

func _shoot_scene(shot_name: String, scene: PackedScene, zoom: float) -> void:
	var holder := _frozen_holder()
	var instance: Node2D = scene.instantiate()
	holder.add_child(instance)
	await _capture_centered(holder, instance, zoom, shot_name)

func _shoot_houses_and_trees() -> void:
	var holder := _frozen_holder()
	var parts_by_slot := BuildingDatabase.scan_parts()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 5:
		var house: ComposedBuilding = load("res://scenes/world/composed_building.tscn").instantiate()
		house.building_data = _random_building(parts_by_slot, rng)
		house.position = Vector2(-900 + i * 420, 0)
		holder.add_child(house)
	var tree_names := ["oak", "pine", "birch", "palm", "spruce", "dead_tree"]
	for i in tree_names.size():
		var tree: ComposedTree = load("res://scenes/world/composed_tree.tscn").instantiate()
		tree.tree_data = load("res://trees/%s.tres" % tree_names[i])
		tree.position = Vector2(-900 + i * 340, 420)
		holder.add_child(tree)
	await _capture_centered(holder, null, 0.75, "houses_trees", Vector2(0, 150))

func _random_building(parts_by_slot: Dictionary, rng: RandomNumberGenerator) -> BuildingData:
	var data := BuildingData.new()
	for slot in parts_by_slot:
		var entries: Array = parts_by_slot[slot]
		if not entries.is_empty():
			data.set_part(slot, entries[rng.randi_range(0, entries.size() - 1)].scene)
	return data

## Loads a whole scene as the running screen for a few seconds and grabs the window.
func _shoot_screen(shot_name: String, scene_path: String) -> void:
	get_window().size = Vector2i(1600, 900)
	var screen: Node = load(scene_path).instantiate()
	get_tree().root.add_child(screen)
	await get_tree().create_timer(3.5).timeout
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	screen.queue_free()
	await get_tree().process_frame

## The ramp jump as it plays, one shot every couple of seconds, then the
## landing side (the crowd and the end wall) at race zoom.
func _shoot_ramp_run() -> void:
	get_window().size = Vector2i(1600, 900)
	var screen: Node = load("res://scenes/race/race_ramp.tscn").instantiate()
	get_tree().root.add_child(screen)
	for i in 6:
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out_dir.path_join("ramp_%d.png" % i))
	var camera := screen.get_node("MainCamera") as CameraFollow
	camera.targets = []
	camera.lock_on(Vector2(7300.0, 2450.0))
	await get_tree().create_timer(2.0).timeout
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join("ramp_landing.png"))
	print("saved ramp shots")
	screen.queue_free()
	await get_tree().process_frame

func _shoot_end_wall(shot_name: String, scene_path: String) -> void:
	get_window().size = Vector2i(1600, 900)
	var screen: Node = load(scene_path).instantiate()
	get_tree().root.add_child(screen)
	await get_tree().create_timer(0.5).timeout
	var wall := screen.find_child("EndWall", true, false) as Node2D
	var camera := screen.get_node("MainCamera") as CameraFollow
	camera.targets = []
	camera.lock_on(wall.global_position + Vector2(-500.0, 0.0))
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
	screen.queue_free()
	await get_tree().process_frame

func _shoot_race(shot_name: String, scene_path: String, seconds: float) -> void:
	get_window().size = Vector2i(1600, 900)
	var screen: Node = load(scene_path).instantiate()
	get_tree().root.add_child(screen)
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)
	screen.queue_free()
	await get_tree().process_frame

func _shoot_row(shot_name: String, scene_paths: Array, zoom: float) -> void:
	var holder := _frozen_holder()
	for i in scene_paths.size():
		var instance: Node2D = load(scene_paths[i]).instantiate()
		instance.position = Vector2(-900 + (i % 4) * 600, -250 + (i / 4) * 600)
		holder.add_child(instance)
	await _capture_centered(holder, null, zoom * 0.6, shot_name, Vector2(0, 50))

## Containers and bins, full (a few seeds, since overflow is random) and emptied.
func _shoot_trash() -> void:
	var holder := _frozen_holder()
	var props := [
		["res://scenes/world/trash_container.tscn", true, 1], ["res://scenes/world/trash_container.tscn", true, 2],
		["res://scenes/world/trash_container.tscn", false, 1], ["res://scenes/world/trash_bin.tscn", true, 1],
		["res://scenes/world/trash_bin.tscn", true, 2], ["res://scenes/world/trash_bin.tscn", true, 3],
		["res://scenes/world/trash_bin.tscn", false, 1],
	]
	for i in props.size():
		var prop: Node2D = load(props[i][0]).instantiate()
		prop.position = Vector2(-600 + (i % 4) * 330, -60 + (i / 4) * 260)
		prop.set("variant_seed", props[i][2])
		holder.add_child(prop)
		prop.set("filled", props[i][1])
		prop.queue_redraw()
	await _capture_centered(holder, null, 1.1, "trash")

func _frozen_holder() -> Node2D:
	var holder := Node2D.new()
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	return holder

func _polygon_bounds(root: Node) -> Rect2:
	var bounds := Rect2()
	var first := true
	for polygon in root.find_children("*", "Polygon2D", true, false):
		var to_root: Transform2D = (root as Node2D).global_transform.affine_inverse() * (polygon as Node2D).global_transform
		for point in (polygon as Polygon2D).polygon:
			var local: Vector2 = to_root * (point + (polygon as Polygon2D).offset)
			if first:
				bounds = Rect2(local, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(local)
	return bounds

func _capture(holder: Node2D, area: Vector2, file_name: String) -> void:
	await _render(holder, Vector2i(area), Vector2.ZERO, 1.0, false, file_name)

func _capture_centered(holder: Node2D, target: Node2D, zoom: float, file_name: String, offset := Vector2.ZERO) -> void:
	var center := (target.position if target != null else Vector2.ZERO) + offset
	await _render(holder, Vector2i(1600, 1000), center, zoom, true, file_name)

func _render(holder: Node2D, size: Vector2i, camera_position: Vector2, zoom: float, centered: bool, file_name: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = BACKGROUND
	backdrop.size = Vector2(size) / zoom
	backdrop.position = camera_position - (Vector2(size) * 0.5 / zoom if centered else Vector2.ZERO)
	viewport.add_child(backdrop)
	var camera := Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER if centered else Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.zoom = Vector2.ONE * zoom
	camera.position = camera_position
	viewport.add_child(camera)
	holder.reparent(viewport)
	for i in 6:
		await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(file_name + ".png")
	viewport.get_texture().get_image().save_png(path)
	print("saved ", path)
	viewport.queue_free()
