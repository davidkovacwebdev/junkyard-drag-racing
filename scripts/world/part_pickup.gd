class_name PartPickup
extends Pickup
## A real, equippable car part pulled out of a bin — the rare drop, and the
## reason it's worth opening every one.
##
## Instead of a drawn glyph the orb carries the part's *own* scene, shrunk down
## and centred inside the ball, so a wheel orb looks like exactly the wheel it
## is. The part is neutralised (frozen, no collision) the same way `CarView`
## treats the parts it builds a car out of: it's decoration in here.

## The part this orb is worth. Set it with `configure()` before adding the orb
## to the tree, so `_ready()` can build the art.
var part: PartData = null

func configure(value: PartData) -> void:
	part = value
	if is_node_ready():
		_apply_tint()
		_build_icon()

func _ready() -> void:
	super()
	_apply_tint()
	_build_icon()

## Colour the ball by what's inside — a rusty body, a steel wheel, a hot engine.
## This is the whole rarity tell, since a part orb has to be recognisable as one
## from across the road before you can read what's in it.
##
## The shades are muted to sit with the props' palette; the point is to be
## distinguishable from each other, not to be bright.
func _apply_tint() -> void:
	if part == null:
		return
	match part.category:
		PartData.Category.BODY:
			orb_color = Color(0.5, 0.72, 0.51, 1.0)
		PartData.Category.WHEEL:
			orb_color = Color(0.46, 0.62, 0.79, 1.0)
		PartData.Category.ENGINE:
			orb_color = Color(0.83, 0.6, 0.33, 1.0)
	queue_redraw()

func grant() -> void:
	if part != null:
		Inventory.add_part(part)

func label_text() -> String:
	if part == null:
		return ""
	return "Found %s!" % part.display_name

## Instance the part's real scene, freeze it, and scale it to sit inside the
## orb. The instance is wrapped in a plain `Node2D` and *that* is scaled: a
## `RigidBody2D`'s own transform belongs to the physics server (it would reset
## the scale within a frame), and scaling the wrapper moves the art just the
## same.
func _build_icon() -> void:
	if _icon != null:
		_icon.queue_free()
		_icon = null
		_icon_center = Vector2.ZERO
	if part == null or part.scene_path.is_empty():
		return
	var instance: Node2D = (load(part.scene_path) as PackedScene).instantiate()
	_neutralize(instance)
	var wrapper := Node2D.new()
	wrapper.name = "Icon"
	wrapper.add_child(instance)
	add_child(wrapper)
	_icon = wrapper
	var bounds := PartScale.measure_bounds(instance)
	if bounds.size.x > 0.0 or bounds.size.y > 0.0:
		# Filling the backing disc right to its edge: with no outline to define
		# the part, it has to be big enough for its own silhouette to read.
		var target := ORB_RADIUS * 1.68
		var factor: float = minf(target / maxf(bounds.size.x, 0.001),
				target / maxf(bounds.size.y, 0.001))
		wrapper.scale = Vector2(factor, factor)
		_icon_center = -bounds.get_center() * factor
	_sync_icon()
	queue_redraw()

## A soft dark disc behind the part. Real part art is drawn in its own palette
## and often ends up the same value as the ball, so without this the wheel inside
## a blue orb is just a smudge. Kept well inside the ball, so a ring of the orb's
## rarity tint still shows around the edge.
func _draw_icon(center: Vector2, radius: float) -> void:
	draw_circle(center, radius * 0.78, Color(0.07, 0.09, 0.11, 0.32))

func _neutralize(node: Node) -> void:
	if node is RigidBody2D:
		node.freeze = true
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_neutralize(child)
