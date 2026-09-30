extends Node2D
## Renders art sheets to PNG so the art can be reviewed side by side:
##   godot res://tools/art_gallery.tscn -- <out_dir> [parts|world|race|ramp|screens|all]
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
	var groups := {"bodies": PartDatabase.bodies, "wheels": PartDatabase.wheels, "engines": PartDatabase.engines}
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

func _shoot_scene(shot_name: String, scene: PackedScene, zoom: float) -> void:
	var holder := _frozen_holder()
	var instance: Node2D = scene.instantiate()
	holder.add_child(instance)
	await _capture_centered(holder, instance, zoom, shot_name)

func _shoot_houses_and_trees() -> void:
	var holder := _frozen_holder()
	var spawner: HouseSpawner = HouseSpawner.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 5:
		var house: ComposedBuilding = load("res://scenes/world/composed_building.tscn").instantiate()
		house.building_data = spawner._random_building(rng)
		house.position = Vector2(-900 + i * 420, 0)
		holder.add_child(house)
	var tree_names := ["oak", "pine", "birch", "palm", "spruce", "dead_tree"]
	for i in tree_names.size():
		var tree: ComposedTree = load("res://scenes/world/composed_tree.tscn").instantiate()
		tree.tree_data = load("res://trees/%s.tres" % tree_names[i])
		tree.position = Vector2(-900 + i * 340, 420)
		holder.add_child(tree)
	spawner.free()
	await _capture_centered(holder, null, 0.75, "houses_trees", Vector2(0, 150))

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
