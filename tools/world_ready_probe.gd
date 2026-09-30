extends Node

const MAIN := preload("res://scenes/world/main.tscn")

func _ready() -> void:
	var wait_start := Time.get_ticks_msec()
	await get_tree().create_timer(12.0).timeout
	print("waited ms=", Time.get_ticks_msec() - wait_start)
	for pass_index in 3:
		print("--- pass ", pass_index)
		var t := Time.get_ticks_usec()
		var world := _load_timed()
		print("total ms=%.1f" % ((Time.get_ticks_usec() - t) / 1000.0))
		world.free()
	get_tree().quit()

func _load_timed() -> Node:
	var world := MAIN.instantiate()
	var sortables := world.get_node("Sortables")
	var top: Array[Node] = []
	for c in world.get_children():
		top.append(c)
		world.remove_child(c)
	var sorted: Array[Node] = []
	for c in sortables.get_children():
		sorted.append(c)
		sortables.remove_child(c)
	add_child(world)
	for c in top:
		if c == sortables:
			world.add_child(c)
			for s in sorted:
				_timed(c, s, "  ")
		else:
			_timed(world, c, "")
	return world

func _timed(parent: Node, child: Node, indent: String) -> void:
	var t := Time.get_ticks_usec()
	parent.add_child(child)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	if ms > 5.0:
		print(indent, child.name, " ms=%.1f" % ms)
