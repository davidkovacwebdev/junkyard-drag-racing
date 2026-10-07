extends Node
## Renders the world map with every collision shape drawn on top, one shot
## per landmark, so footprints can be checked against the art:
##   godot res://tools/collision_audit.tscn -- <out_dir> [node_name ...] [--zoom=1.5] [--car=x,y] --no-save
## `--car` parks the player car at that offset from each target (default 0,260).
## `--clean` leaves the collision shapes out, for judging the art.
## `--save-car=0` drives the selected car from that save slot instead (read only).

const MAIN := preload("res://scenes/world/main.tscn")
const SHOT_SIZE := Vector2i(1600, 1000)
const DEFAULT_ZOOM := 0.8
const SKIPPED := ["PlayerCar", "Trash", "Gulls", "Tumbleweeds", "FishingBoat"]

var _camera: Camera2D

func _ready() -> void:
	get_tree().debug_collisions_hint = not "--clean" in OS.get_cmdline_user_args()
	var args := Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return not a.begins_with("--"))
	var out_dir: String = args.pop_front() if not args.is_empty() else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = SHOT_SIZE
	var world := MAIN.instantiate()
	add_child(world)
	var player := world.get_node("Sortables/PlayerCar") as Node2D
	(player.get_node("Camera2D") as Camera2D).enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("UI").visible = false
	player.get_node("InteractionZone").queue_free()
	var slot := _named_arg("--save-car=")
	if not slot.is_empty():
		var save := ResourceLoader.load("user://save_%s.tres" % slot, "", ResourceLoader.CACHE_MODE_IGNORE)
		var view := player.find_child("Visual", true, false) as CarView
		view.build_from(save.get("owned_cars")[0])
		view.fit_collision(player.get_node("CollisionShape2D"), player.get_node("WalkerCollisionShape2D"))
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * _zoom_arg()
	world.add_child(_camera)
	_camera.make_current()
	await get_tree().process_frame
	_raise_shapes(world)
	for target in _targets(world, args):
		_camera.global_position = target.global_position
		player.global_position = target.global_position + _car_offset_arg()
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot_name := "%s_%s" % [target.get_parent().name, target.name]
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	get_tree().quit()

## Names may also be paths below the world or Sortables, e.g. "DragStrip/Entrance".
func _targets(world: Node, names: Array) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for name: String in names:
		if not "/" in name:
			continue
		for parent: Node in [world, world.get_node("Sortables")]:
			if parent.has_node(name):
				found.append(parent.get_node(name))
	names = names.filter(func(n: String) -> bool: return not "/" in n)
	if found.size() > 0 and names.is_empty():
		return found
	for parent: Node in [world, world.get_node("Sortables")]:
		for child in parent.get_children():
			if not child is Node2D or child.name in SKIPPED or child.name == "Sortables":
				continue
			if names.is_empty() or String(child.name) in names:
				found.append(child)
	return found

func _zoom_arg() -> float:
	var value := _named_arg("--zoom=")
	return value.to_float() if not value.is_empty() else DEFAULT_ZOOM

func _car_offset_arg() -> Vector2:
	var parts := _named_arg("--car=").split(",")
	return Vector2(parts[0].to_float(), parts[1].to_float()) if parts.size() == 2 else Vector2(0.0, 260.0)

func _named_arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""

## Debug shapes draw with their node, so art added after them hides them.
## Skips the car's part art: its shapes are dead, and raising them drags art up.
func _raise_shapes(node: Node) -> void:
	if node is CarView:
		return
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.z_index = 500
	for child in node.get_children():
		_raise_shapes(child)
