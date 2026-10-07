class_name ItemPickup
extends Pickup
## A trunk item lying on the road (Grandpa's package, knocked off the garbage
## truck). Like `PartPickup` the orb carries the item's own icon, shrunk to
## fit. Driving over it puts the item in the trunk; with the trunk full it
## stays put and says so, rather than vanishing with the item.

## Item icons are authored in a roughly 64 px box (see ItemData.icon_scene).
const ICON_SIZE := 64.0
## How often a full trunk complains while the car sits on the orb.
const FULL_COOLDOWN := 2.0

## The item this orb is worth. Set it with `configure()` before adding the
## orb to the tree, so `_ready()` can build the art.
var item: ItemData = null

var _full_cooldown: float = 0.0

func configure(value: ItemData) -> void:
	item = value
	if is_node_ready():
		_build_icon()

func _ready() -> void:
	super()
	orb_color = Color(0.86, 0.7, 0.36, 1.0)
	glow_color = Color(0.95, 0.75, 0.1, 1.0)
	_build_icon()

func _physics_process(delta: float) -> void:
	_full_cooldown -= delta
	super(delta)

func collect(by: Node = null) -> void:
	if item != null and not Inventory.has_item(item.id) and Inventory.is_trunk_full():
		if _full_cooldown <= 0.0:
			_full_cooldown = FULL_COOLDOWN
			Sfx.play(&"denied", -6.0, 0.0)
			_spawn_float_text("Trunk's full!")
		return
	super(by)

func grant() -> void:
	if item != null:
		Inventory.give_item(item)

func collect_sound() -> StringName:
	return &"part_pickup"

func label_text() -> String:
	return "Got the %s!" % item.display_name if item != null else ""

func _build_icon() -> void:
	if _icon != null:
		_icon.queue_free()
		_icon = null
	if item == null or item.icon_scene == null:
		return
	var wrapper := Node2D.new()
	wrapper.name = "Icon"
	wrapper.add_child(item.icon_scene.instantiate())
	wrapper.scale = Vector2.ONE * (ORB_RADIUS * 1.68 / ICON_SIZE)
	add_child(wrapper)
	_icon = wrapper
	_icon_center = Vector2.ZERO
	_sync_icon()
	queue_redraw()

## The same soft dark disc `PartPickup` puts behind its art.
func _draw_icon(center: Vector2, radius: float) -> void:
	draw_circle(center, radius * 0.78, Color(0.07, 0.09, 0.11, 0.32))
