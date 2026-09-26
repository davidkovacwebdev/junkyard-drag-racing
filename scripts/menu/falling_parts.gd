class_name FallingParts
extends Control
## Real car parts (bodies, wheels, engines) tumbling down behind the menu. The
## art is copied straight off each part's scene, so any new part joins the
## shower on its own. Smaller parts are farther away: darker, slower, drawn
## behind the bigger ones.

@export var max_parts: int = 16
@export var spawn_interval := Vector2(0.35, 0.9)
@export var part_size := Vector2(50.0, 150.0)
@export var fall_speed := Vector2(90.0, 200.0)
@export var gravity: float = 60.0
@export var max_spin: float = 1.8
## How much the farthest parts are tinted toward `distance_tint`.
@export var distance_tint := Color(0.80, 0.68, 0.49)
@export var max_distance_tint: float = 0.55

var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
## Scene path -> art template (Node2D of Polygon2D copies, centred on origin).
var _templates: Dictionary = {}
var _falling: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	# Start mid-shower rather than on an empty sky.
	for i in max_parts / 2:
		_spawn(_rng.randf_range(-0.1, 0.8) * size.y)

func _exit_tree() -> void:
	for template: Node2D in _templates.values():
		template.free()
	_templates.clear()

func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _falling.size() < max_parts:
		_spawn(-part_size.y)
		_spawn_timer = _rng.randf_range(spawn_interval.x, spawn_interval.y)

	for i in range(_falling.size() - 1, -1, -1):
		var part := _falling[i]
		var node: Node2D = part.node
		var velocity: Vector2 = part.velocity
		velocity.y += gravity * part.depth * delta
		part.velocity = velocity
		node.position += velocity * delta
		node.rotation += part.spin * delta
		if node.position.y > size.y + part_size.y:
			node.queue_free()
			_falling.remove_at(i)

func _spawn(start_y: float) -> void:
	var paths := _part_scene_paths()
	if paths.is_empty():
		return
	var art := _template_for(paths[_rng.randi() % paths.size()]).duplicate() as Node2D
	# depth 0 = far away, 1 = close.
	var depth := _rng.randf()
	var bounds := PartScale.measure_bounds(art)
	var longest := maxf(bounds.size.x, bounds.size.y)
	var target := lerpf(part_size.x, part_size.y, depth)
	art.scale = Vector2.ONE * (target / longest if longest > 0.0 else 1.0)
	art.position = Vector2(_rng.randf_range(0.0, size.x), start_y)
	art.rotation = _rng.randf_range(-PI, PI)
	art.modulate = Color.WHITE.lerp(distance_tint, (1.0 - depth) * max_distance_tint)
	_insert_by_depth(art, depth)
	_falling.append({
		node = art,
		depth = depth,
		velocity = Vector2(_rng.randf_range(-20.0, 20.0), lerpf(fall_speed.x, fall_speed.y, depth)),
		spin = _rng.randf_range(-max_spin, max_spin),
	})

## Farther parts go behind nearer ones.
func _insert_by_depth(art: Node2D, depth: float) -> void:
	var index := 0
	for part in _falling:
		if part.depth < depth:
			index = maxi(index, (part.node as Node).get_index() + 1)
	add_child(art)
	move_child(art, mini(index, get_child_count() - 1))

func _part_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	for category: Array in [PartDatabase.bodies, PartDatabase.wheels, PartDatabase.engines]:
		for part: PartData in category:
			if part != null and not part.scene_path.is_empty():
				paths.append(part.scene_path)
	return paths

## The part's Polygon2D art copied into a plain Node2D (no physics, no scripts),
## centred on the origin so it spins around its middle. Built once per part.
func _template_for(scene_path: String) -> Node2D:
	if _templates.has(scene_path):
		return _templates[scene_path]
	var instance := (load(scene_path) as PackedScene).instantiate()
	var art := Node2D.new()
	var inner := Node2D.new()
	art.add_child(inner)
	var stack: Array[Array] = [[instance, Transform2D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var current: Node = entry[0]
		var xform: Transform2D = entry[1]
		if current != instance and current is Node2D:
			xform = xform * (current as Node2D).get_transform()
		if current is Polygon2D:
			var source := current as Polygon2D
			var copy := Polygon2D.new()
			copy.polygon = source.polygon
			copy.color = source.color
			copy.transform = xform
			inner.add_child(copy)
		for child in current.get_children():
			stack.append([child, xform])
	instance.free()
	inner.position = -PartScale.measure_bounds(inner).get_center()
	_templates[scene_path] = art
	return art
