class_name PartIcon
extends SubViewportContainer
## Renders a live snapshot of a part's own scene as its "icon" — parts
## have no separate sprite/texture, their Polygon2D shapes are the only
## art that exists, so this instances the real part scene into a small
## SubViewport and auto-fits/centers it instead of needing hand-drawn
## icon images.

@onready var _viewport: SubViewport = $SubViewport

## Nearest ancestor that clips its children (a ScrollContainer), or null.
var _clipping_ancestor: Control = null
var _on_screen := true

func _enter_tree() -> void:
	_clipping_ancestor = _find_clipping_ancestor()

## Long lists (F1 menu, garage) hold hundreds of icons, each a live SubViewport
## with animated part scripts. Ones that are hidden or scrolled out of view stop
## rendering and processing until they come back.
func _process(_delta: float) -> void:
	var on_screen := _is_on_screen()
	if on_screen == _on_screen:
		return
	_on_screen = on_screen
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if on_screen else SubViewport.UPDATE_DISABLED
	_viewport.process_mode = Node.PROCESS_MODE_INHERIT if on_screen else Node.PROCESS_MODE_DISABLED

func _is_on_screen() -> bool:
	if not is_visible_in_tree():
		return false
	var rect := get_global_rect()
	if is_instance_valid(_clipping_ancestor) and not rect.intersects(_clipping_ancestor.get_global_rect()):
		return false
	var screen_rect := get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)
	return screen_rect.intersects(get_viewport_rect())

func _find_clipping_ancestor() -> Control:
	var node := get_parent()
	while node != null:
		if node is Control and node.clip_contents:
			return node
		node = node.get_parent()
	return null

## The live-rendered contents of this icon, reusable elsewhere (e.g. as a
## drag preview) without re-instancing the part scene a second time.
func get_preview_texture() -> Texture2D:
	return _viewport.get_texture()

func show_part(part: PartData) -> void:
	for child in _viewport.get_children():
		child.queue_free()
	var instance := PartFactory.instantiate(part)
	if instance == null:
		return
	if instance is RigidBody2D:
		# Same physics rigs the drag-race rig drives — freeze so the icon
		# just sits still instead of falling under gravity.
		instance.freeze = true
	_viewport.add_child(instance)
	_fit_and_center(instance)

func _fit_and_center(instance: Node2D) -> void:
	var bounds := PartScale.measure_bounds(instance)
	if bounds.size == Vector2.ZERO:
		return
	var viewport_size := Vector2(_viewport.size)
	var padding := 0.85
	var scale_factor: float = minf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y) * padding
	instance.scale = Vector2(scale_factor, scale_factor)
	instance.position = viewport_size / 2.0 - bounds.get_center() * scale_factor
