class_name OffscreenCuller
extends Node
## Pauses purely cosmetic animators (bobbing boats, flapping flags, pecking
## chickens, pump jacks...) while they're off screen, so they neither tick nor
## redraw. Godot already skips rendering off-screen items, but not the
## `_process` + `queue_redraw()` that rebuilds their art every frame.
##
## Animators opt in with `add_to_group(OffscreenCuller.GROUP)`. Only add things
## whose processing is for looks: anything that has to keep running out of
## sight (the garbage truck, spawners, cutscene actors) must stay out.

const GROUP := &"cull_offscreen"
## World pixels past the screen edge that still count as on screen, so big
## props hanging off a node's origin wake up before any of them shows.
const MARGIN := 600.0

func _process(_delta: float) -> void:
	var view := get_viewport()
	var screen := view.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, view.get_visible_rect().size)
	screen = screen.grow(MARGIN)
	for node in get_tree().get_nodes_in_group(GROUP):
		var on_screen := screen.has_point((node as Node2D).global_position)
		var mode := Node.PROCESS_MODE_INHERIT if on_screen else Node.PROCESS_MODE_DISABLED
		if node.process_mode != mode:
			node.process_mode = mode
