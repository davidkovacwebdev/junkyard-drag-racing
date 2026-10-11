@tool
class_name BlockedBridge
extends Node2D
## A long bridge running west from its origin across open water, closed off at
## the near end by a `BridgeBarricade`. Drawn back to front so it reads as a
## raised span: water shadow, piers, girder face, deck, then the rail on top.
## The origin is the middle of the deck at the land end.
##
## The deck drives like a road and counts as land, never sea (`is_on_deck()`,
## which PlayerCar and TerrainNetwork ask through the `GROUP`). Both railings
## are solid, so the car can't drive off the sides. Each railing is drawn by
## its own node in the Y-sorted `sortables_path`, sorted on its kerb, so a car
## behind a railing (up on the deck, or on land north of it) tucks behind it.
## The bridge has two levels. Up top is the deck, reached from either end.
## Down below is the ground under it, reached from the shade south of the deck
## or the strip just north of it (`is_under_deck()`). A car keeps its level while it's anywhere over the
## bridge (`is_car_under()`). Underneath, PlayerCar drops below the bridge's
## draw layer and ignores `DECK_LAYER` (railings, barricade), so it drives
## straight beneath them.

const DECK_COLOR := Color("4a6e64")
const CONCRETE := Color(0.62, 0.6, 0.55)
const CONCRETE_SHADE := Color(0.49, 0.47, 0.43)
const CONCRETE_DARK := Color(0.38, 0.36, 0.33)
const LANE_LINE := Color(0.95, 0.93, 0.68, 0.5)

const GROUP := &"bridge_deck"
## Physics layer for everything up on the deck: the railings and the barricade.
const DECK_LAYER := 16
## How far past the deck a car under it still counts as under, so it is well
## clear of the railings before they turn solid for it again.
const UNDER_EXIT_MARGIN := 120.0

@export var length: float = 8320.0:
	set(value):
		length = value
		queue_redraw()
@export var deck_width: float = 216.0:
	set(value):
		deck_width = value
		queue_redraw()
@export var pier_spacing: float = 1040.0
@export var pier_width: float = 110.0
@export var girder_height: float = 56.0
@export var pier_drop: float = 130.0
@export var rail_width: float = 22.0
@export var rail_face_height: float = 30.0
@export var post_spacing: float = 832.0
@export var post_width: float = 36.0
@export var post_height: float = 56.0
@export var top_rail_thickness: float = 14.0
@export var shadow_offset: Vector2 = Vector2(30.0, 190.0)
@export var lane_line_width: float = 10.0
## How far north of the deck a car still drops in under it.
@export var north_entry_depth: float = 120.0
@export var sortables_path: NodePath = ^"../Sortables"

var _north_railing: Node2D
var _south_railing: Node2D

func _ready() -> void:
	_north_railing = _add_railing_node(_draw_north_railing)
	_south_railing = _add_railing_node(_draw_south_railing)
	_place_railing_nodes()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	_build_railing_collision()
	var sortables := get_node_or_null(sortables_path)
	if sortables != null:
		_north_railing.reparent.call_deferred(sortables)
		_south_railing.reparent.call_deferred(sortables)

func _add_railing_node(drawer: Callable) -> Node2D:
	var railing := Node2D.new()
	railing.draw.connect(drawer)
	add_child(railing, false, Node.INTERNAL_MODE_BACK)
	return railing

func _place_railing_nodes() -> void:
	_north_railing.position = Vector2(0.0, _north_kerb_top())
	_south_railing.position = Vector2(0.0, _south_kerb_top())

func _north_kerb_top() -> float:
	return -deck_width / 2.0 - rail_width

func _south_kerb_top() -> float:
	return deck_width / 2.0 - rail_width * 0.2

func _build_railing_collision() -> void:
	var railings := StaticBody2D.new()
	railings.collision_layer = DECK_LAYER
	add_child(railings)
	_add_railing_shape(railings, _north_kerb_top())
	_add_railing_shape(railings, _south_kerb_top())

func _add_railing_shape(railings: StaticBody2D, kerb_top: float) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, rail_width)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(-length / 2.0, kerb_top + rail_width / 2.0)
	railings.add_child(collision)

## Whether `world_point` is up on the deck (not under it in the water).
func is_on_deck(world_point: Vector2) -> bool:
	var local := to_local(world_point)
	return local.x <= 0.0 and local.x >= -length and absf(local.y) <= deck_width * 0.5

## Whether `world_point` is over the deck, grown by `margin` on every side.
func is_over_footprint(world_point: Vector2, margin: float = 0.0) -> bool:
	var local := to_local(world_point)
	return local.x <= margin and local.x >= -length - margin \
			and absf(local.y) <= deck_width * 0.5 + margin

## Whether `world_point` is just off either side of the deck, past a railing,
## where the ground runs in under the span: the shade to the south, or the
## strip along the north edge.
func is_under_deck(world_point: Vector2) -> bool:
	var local := to_local(world_point)
	if local.x > 0.0 or local.x < -length:
		return false
	var half := deck_width / 2.0
	var in_south_shade := local.y > half and local.y <= half + girder_height + shadow_offset.y
	var in_north_strip := local.y < -half and local.y >= -half - north_entry_depth
	return in_south_shade or in_north_strip

## The deck's outline in world space.
func deck_polygon() -> PackedVector2Array:
	var half := deck_width / 2.0
	return PackedVector2Array([
		to_global(Vector2(0.0, -half)), to_global(Vector2(-length, -half)),
		to_global(Vector2(-length, half)), to_global(Vector2(0.0, half)),
	])

## Whether `world_point` is on any bridge deck in the scene.
static func any_deck_under(tree: SceneTree, world_point: Vector2) -> bool:
	for bridge in tree.get_nodes_in_group(GROUP):
		if (bridge as BlockedBridge).is_on_deck(world_point):
			return true
	return false

## Whether a car at `world_point` is down under a bridge, given whether it
## was last frame. The ground just off either side of a deck always means
## under. Over the deck (or just past it) the car keeps the level it came in on.
static func is_car_under(tree: SceneTree, world_point: Vector2, was_under: bool) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		var bridge := node as BlockedBridge
		if bridge.is_under_deck(world_point):
			return true
		if was_under and bridge.is_over_footprint(world_point, UNDER_EXIT_MARGIN):
			return true
	return false

func _draw() -> void:
	var half := deck_width / 2.0
	_draw_water_shadow(half)
	_draw_piers(half)
	draw_rect(Rect2(-length, half, length, girder_height), CONCRETE_DARK)
	draw_rect(Rect2(-length, -half, length, deck_width), DECK_COLOR)
	draw_rect(Rect2(-length, -lane_line_width / 2.0, length, lane_line_width), LANE_LINE)
	if _south_railing == null:
		return
	if _south_railing.get_parent() == self:
		_place_railing_nodes()
	_north_railing.queue_redraw()
	_south_railing.queue_redraw()

## Drawn on `_north_railing`, whose origin sits on the north kerb top.
func _draw_north_railing() -> void:
	_draw_rail(_north_railing, 0.0)
	_draw_railing(_north_railing, 0.0)

## Drawn on `_south_railing`, whose origin sits on the south kerb top.
func _draw_south_railing() -> void:
	_draw_rail(_south_railing, 0.0)
	_south_railing.draw_rect(Rect2(-length, rail_width, length, rail_face_height), CONCRETE_SHADE)
	_draw_railing(_south_railing, 0.0)

func _draw_water_shadow(half: float) -> void:
	draw_rect(Rect2(Vector2(-length, -half) + shadow_offset, Vector2(length, deck_width + girder_height)), UiPalette.SHADOW)

func _draw_piers(half: float) -> void:
	var pier_count := int(length / pier_spacing)
	for index in pier_count:
		var center_x := -pier_spacing * (index + 0.5)
		draw_rect(Rect2(center_x - pier_width / 2.0, half + girder_height, pier_width, pier_drop), CONCRETE_SHADE)
		draw_rect(Rect2(center_x + pier_width / 2.0 - 30.0, half + girder_height, 30.0, pier_drop), CONCRETE_DARK)

func _draw_rail(canvas: CanvasItem, top: float) -> void:
	canvas.draw_rect(Rect2(-length, top, length, rail_width), CONCRETE)

func _draw_railing(canvas: CanvasItem, kerb_top: float) -> void:
	var post_count := int(length / post_spacing) + 1
	for index in post_count:
		var post_x := -post_spacing * index
		canvas.draw_rect(Rect2(post_x - post_width / 2.0, kerb_top - post_height, post_width, post_height + rail_width), CONCRETE_SHADE)
		canvas.draw_rect(Rect2(post_x + post_width / 2.0 - 10.0, kerb_top - post_height, 10.0, post_height + rail_width), CONCRETE_DARK)
	canvas.draw_rect(Rect2(-length, kerb_top - post_height, length, top_rail_thickness), CONCRETE)
