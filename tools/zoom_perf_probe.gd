extends Node

const MAIN := preload("res://scenes/world/main.tscn")
const SAMPLE_FRAMES := 90
var _world: Node
var _car: Node2D
var _cam: Camera2D
var _targets: Array = []
var _target_index := -1
var _frames := 0
var _time := 0.0
var _draws := 0.0
var _objects := 0.0

func _ready() -> void:
	SaveSystem.process_mode = Node.PROCESS_MODE_DISABLED
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_world = MAIN.instantiate()
	add_child(_world)
	_car = get_tree().get_first_node_in_group(PlayerCar.GROUP)
	_cam = _car.get_node("Camera2D")
	_cam.set("zoom_speed", 1000.0)
	var zoom := 0.25
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zoom="):
			zoom = arg.trim_prefix("--zoom=").to_float()
	_cam.set("_target_zoom", zoom)
	_cam.zoom = Vector2(zoom, zoom)
	await get_tree().process_frame
	await get_tree().process_frame
	for child in _world.get_children():
		_targets.append(child)
	for child in _world.get_node("Sortables").get_children():
		_targets.append(child)
	for child in _world.get_children():
		print(child.name, " canvas_items=", _count(child))
	for child in _world.get_node("Sortables").get_children():
		print("  Sortables/", child.name, " canvas_items=", _count(child))

func _count(node: Node) -> int:
	var n := 1 if node is CanvasItem else 0
	for c in node.get_children():
		n += _count(c)
	return n

func _process(delta: float) -> void:
	_frames += 1
	if _frames < 30:
		return
	_time += delta
	_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	if _frames < 30 + SAMPLE_FRAMES:
		return
	var label: String = "baseline" if _target_index < 0 else "hide " + str(_targets[_target_index].get_path()).get_file() + "(" + _targets[_target_index].name + ")"
	print("%-40s ms=%.2f draws=%.0f objects=%.0f" % [label, _time / SAMPLE_FRAMES * 1000.0, _draws / SAMPLE_FRAMES, _objects / SAMPLE_FRAMES])
	if _target_index >= 0 and _targets[_target_index] is CanvasItem:
		_targets[_target_index].visible = true
	_target_index += 1
	while _target_index < _targets.size() and not (_targets[_target_index] is CanvasItem and _targets[_target_index] != _car):
		_target_index += 1
	if _target_index >= _targets.size():
		get_tree().quit()
		return
	_targets[_target_index].visible = false
	_frames = 0
	_time = 0.0
	_draws = 0.0
	_objects = 0.0
