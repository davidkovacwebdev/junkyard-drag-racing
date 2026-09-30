extends Node
## Frame cost per category of world content at the player's max zoom-out.
## Hides one whole category (every house, every tree, all trash...) at a time
## and prints how much the frame gets cheaper.

const MAIN := preload("res://scenes/world/main.tscn")
const WARMUP_FRAMES := 30
const SAMPLE_FRAMES := 90

var _world: Node
var _groups: Array = []
var _group_index := -1
var _frames := 0
var _time := 0.0
var _draws := 0.0
var _baseline_ms := 0.0
var _measuring_baseline := true
var _disable_mode := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_world = MAIN.instantiate()
	add_child(_world)
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP)
	var camera: Camera2D = car.get_node("Camera2D")
	var max_zoom_out: float = camera.get("min_zoom")
	camera.set("zoom_speed", 1000.0)
	camera.set("_target_zoom", max_zoom_out)
	camera.zoom = Vector2(max_zoom_out, max_zoom_out)
	_disable_mode = "--mode=disable" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	await get_tree().process_frame
	_collect_groups(car)
	_group_index = 0

func _collect_groups(car: Node) -> void:
	var by_key := {}
	var sortables := _world.get_node("Sortables")
	for child in _world.get_children():
		if child != sortables:
			_add_to_group(by_key, child.name, child)
	for child in sortables.get_children():
		if child == car:
			continue
		_add_to_group(by_key, "Sortables/" + _category_of(child), child)
	for key in by_key:
		_groups.append({"name": key, "nodes": by_key[key]})

func _category_of(node: Node) -> String:
	if not node.scene_file_path.is_empty():
		return node.scene_file_path.get_file().get_basename()
	var script: Script = node.get_script()
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return node.name.rstrip("0123456789")

func _add_to_group(by_key: Dictionary, key: String, node: Node) -> void:
	if not (node is CanvasItem):
		return
	if not by_key.has(key):
		by_key[key] = []
	by_key[key].append(node)

func _process(delta: float) -> void:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return
	_time += delta
	_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if _frames < WARMUP_FRAMES + SAMPLE_FRAMES:
		return
	var ms := _time / SAMPLE_FRAMES * 1000.0
	var group: Dictionary = _groups[_group_index]
	if _measuring_baseline:
		_baseline_ms = ms
		_set_group_active(group, false)
	else:
		print("%-40s base=%.2f without=%.2f saves=%.2f draws=%.0f" % [group["name"] + " x" + str(group["nodes"].size()),
				_baseline_ms, ms, _baseline_ms - ms, _draws / SAMPLE_FRAMES])
		_set_group_active(group, true)
		_group_index += 1
		if _group_index >= _groups.size():
			get_tree().quit()
			return
	_measuring_baseline = not _measuring_baseline
	_frames = 0
	_time = 0.0
	_draws = 0.0

func _set_group_active(group: Dictionary, active: bool) -> void:
	if _disable_mode:
		for node in group["nodes"]:
			_set_processing_recursive(node, active)
	else:
		_set_group_visible(group, active)

func _set_processing_recursive(node: Node, active: bool) -> void:
	node.set_process(active and node.has_method("_process"))
	node.set_physics_process(active and node.has_method("_physics_process"))
	for child in node.get_children():
		_set_processing_recursive(child, active)

func _set_group_visible(group: Dictionary, shown: bool) -> void:
	for node in group["nodes"]:
		(node as CanvasItem).visible = shown
