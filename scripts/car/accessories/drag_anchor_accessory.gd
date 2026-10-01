class_name DragAnchorAccessory
extends CarAccessory
## An anchor chained to the back of the car, lying on the ground behind it and
## dragged along: it trails further back and hops on the bumps the faster the
## car goes, and grinds while it's moving. The ground is wherever the bottoms
## of the car's wheels are.

@export var drag_distance: float = 64.0
## Extra trail at full speed, on top of `drag_distance`.
@export var speed_trail: float = 18.0
@export var hop_height: float = 5.0
@export var hop_rate: float = 11.0
@export var chain_thickness: float = 5.0
@export var scrape_volume_db: float = -16.0

## Where the chain meets the anchor, in the anchor's own space.
const RING_POINT := Vector2(0, -19)
## The ground when the car has no wheels to stand on.
const WHEELLESS_GROUND_DROP := 12.0

@onready var _anchor: Node2D = $Anchor
@onready var _chain: Polygon2D = $Chain

var _body: CarBody
var _wheels: Array[Node2D] = []
## Each wheel's reach from its centre, measured once it's in the tree.
var _wheel_reaches: Dictionary = {}
var _time: float = 0.0
var _scrape: SustainedSound

func _ready() -> void:
	super()
	if audible:
		_scrape = SustainedSound.new()
		_scrape.sound_name = &"anchor_drag_loop"
		_scrape.base_volume_db = scrape_volume_db + (RaceCarAudio.mix_db(self) if in_race else 0.0)
		add_child(_scrape)

func attach_to_body(body: CarBody) -> void:
	_body = body

func paint_wheel(wheel: Node2D) -> void:
	_wheels.append(wheel)
	_drag(0.0)

func _process(delta: float) -> void:
	super(delta)
	if _body == null:
		return
	_time += delta
	var speed := speed_fraction()
	_drag(speed)
	if _scrape != null:
		_scrape.set_level(speed)

## Lays the anchor on the ground behind the car, hopping with `speed` (0..1),
## and stretches the chain out to it.
func _drag(speed: float) -> void:
	var hop := absf(sin(_time * hop_rate)) * hop_height * speed
	_anchor.position = Vector2(-drag_distance - speed_trail * speed, _ground_y() - position.y - hop)
	_anchor.rotation = sin(_time * hop_rate * 0.5) * 0.12 * speed
	_chain.polygon = FlatProps.sliver(Vector2.ZERO, _anchor.position + RING_POINT.rotated(_anchor.rotation), chain_thickness)

## The bottom of the lowest wheel, in the body's space.
func _ground_y() -> float:
	var ground_y := -INF
	for wheel in _wheels:
		if not is_instance_valid(wheel) or not wheel.is_inside_tree():
			continue
		var reach := _wheel_reach(wheel) * wheel.global_scale.y / _body.global_scale.y
		ground_y = maxf(ground_y, _body.to_local(wheel.global_position).y + reach)
	if ground_y == -INF:
		return _body.outline_bounds().end.y + WHEELLESS_GROUND_DROP
	return ground_y

## How far the wheel's art reaches from its centre, whichever way it's turned.
func _wheel_reach(wheel: Node2D) -> float:
	if _wheel_reaches.has(wheel):
		return _wheel_reaches[wheel]
	var reach := 0.0
	var to_wheel := wheel.global_transform.affine_inverse()
	for polygon_node in wheel.find_children("*", "Polygon2D", true, false):
		var polygon := polygon_node as Polygon2D
		var to_wheel_space := to_wheel * polygon.global_transform
		for point in polygon.polygon:
			reach = maxf(reach, (to_wheel_space * point).length())
	_wheel_reaches[wheel] = reach
	return reach
