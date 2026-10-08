extends Node
## Frame cost with the player car parked at each landmark, then, at the worst
## spot, the cost of each world group found by hiding them one at a time:
##   godot res://tools/location_perf_probe.tscn -- [--zoom=1.0] [--at=Farm] [--inside=Farm,Junkyard] --no-save
## `--at` skips the tour and breaks down that one landmark. A zoom below the
## binoculars' limit (e.g. 0.03) uses traveler mode, like F6.
## `--inside` breaks those groups down child by child instead of touring.

const MAIN := preload("res://scenes/world/main.tscn")
const WARMUP_FRAMES := 30
const SAMPLE_FRAMES := 90
const SKIPPED := ["PlayerCar", "Gulls", "Tumbleweeds", "FishingBoat", "Trash"]

var _world: Node
var _player: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_world = MAIN.instantiate()
	add_child(_world)
	_player = get_tree().get_first_node_in_group(PlayerCar.GROUP)
	var camera: Camera2D = _player.get_node("Camera2D")
	camera.set("zoom_speed", 1000.0)
	var zoom := _zoom_arg()
	if zoom < WorldCamera.BINOCULARS_MIN_ZOOM:
		_player.set_traveling(true)
		camera.set("_traveler_zoom", zoom)
	else:
		camera.set("_target_zoom", zoom)
	camera.zoom = Vector2(zoom, zoom)
	var inside := _named_arg("--inside=")
	if not inside.is_empty():
		await _break_down(inside.split(","))
		get_tree().quit()
		return
	var worst: Node2D = null
	var worst_ms := 0.0
	var spots := _landmarks()
	var at := _named_arg("--at=")
	if not at.is_empty():
		spots = spots.filter(func(spot: Node2D) -> bool: return spot.name == at)
	for spot in spots:
		_player.global_position = spot.global_position + Vector2(0.0, 300.0)
		var ms := await _measure()
		print("at %-24s ms=%.2f draws=%d" % [spot.name, ms, _draw_calls()])
		if ms > worst_ms:
			worst_ms = ms
			worst = spot
	_player.global_position = worst.global_position + Vector2(0.0, 300.0)
	var baseline_draws := _draw_calls()
	print("--- groups at ", worst.name, " baseline ms=%.2f draws=%d" % [worst_ms, baseline_draws])
	for group in _groups():
		group.visible = false
		var ms := await _measure()
		var draws := _draw_calls()
		group.visible = true
		print("hide %-28s saves ms=%.2f draws=%d" % [group.name, worst_ms - ms, baseline_draws - draws])
	get_tree().quit()

func _measure() -> float:
	for i in WARMUP_FRAMES:
		await get_tree().process_frame
	var start := Time.get_ticks_usec()
	for i in SAMPLE_FRAMES:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - start) / 1000.0 / SAMPLE_FRAMES

func _landmarks() -> Array[Node2D]:
	var found: Array[Node2D] = []
	for parent: Node in [_world, _world.get_node("Sortables")]:
		for child in parent.get_children():
			if child is Node2D and child.get_child_count() > 0 and not child.name in SKIPPED and child.name != "Sortables" \
					and not String(child.name).begins_with("ComposedTree") and not String(child.name).begins_with("House"):
				found.append(child)
	return found

func _groups() -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	for parent: Node in [_world, _world.get_node("Sortables")]:
		for child in parent.get_children():
			if child is CanvasItem and child != _player:
				found.append(child)
	return found

func _break_down(names: PackedStringArray) -> void:
	var baseline := await _measure()
	print("--- baseline ms=%.2f" % baseline)
	for name in names:
		var group := _world.get_node("Sortables").get_node(name)
		for child in group.find_children("*", "CanvasItem", false, false):
			child.visible = false
			var ms := await _measure()
			child.visible = true
			print("hide %s/%-24s saves ms=%.2f" % [name, child.name, baseline - ms])

func _draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func _zoom_arg() -> float:
	var value := _named_arg("--zoom=")
	return value.to_float() if not value.is_empty() else 1.0

func _named_arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""
