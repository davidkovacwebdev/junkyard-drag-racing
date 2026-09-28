class_name PartIcon
extends SubViewportContainer
## Renders a live snapshot of a part's own scene as its "icon" — parts
## have no separate sprite/texture, their Polygon2D shapes are the only
## art that exists, so this instances the real part scene into a small
## SubViewport and auto-fits/centers it instead of needing hand-drawn
## icon images.

@onready var _viewport: SubViewport = $SubViewport

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
