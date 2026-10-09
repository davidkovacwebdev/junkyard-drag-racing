@tool
class_name BlockedBridge
extends Node2D
## A long bridge running west from its origin across open water, closed off at
## the near end by a `BridgeBarricade`. Drawn back to front so it reads as a
## raised span: water shadow, piers, girder face, deck, then the rail on top.
## The origin is the middle of the deck at the land end.
##
## The deck drives like a road, never like sea (`is_on_deck()`, which
## PlayerCar asks through the `GROUP`).

const DECK_COLOR := Color("4a6e64")
const CONCRETE := Color(0.62, 0.6, 0.55)
const CONCRETE_SHADE := Color(0.49, 0.47, 0.43)
const CONCRETE_DARK := Color(0.38, 0.36, 0.33)
const LANE_LINE := Color(0.95, 0.93, 0.68, 0.5)

const GROUP := &"bridge_deck"

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

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)

## Whether `world_point` is up on the deck (not under it in the water).
func is_on_deck(world_point: Vector2) -> bool:
	var local := to_local(world_point)
	return local.x <= 0.0 and local.x >= -length and absf(local.y) <= deck_width * 0.5

## Whether `world_point` is on any bridge deck in the scene.
static func any_deck_under(tree: SceneTree, world_point: Vector2) -> bool:
	for bridge in tree.get_nodes_in_group(GROUP):
		if (bridge as BlockedBridge).is_on_deck(world_point):
			return true
	return false

func _draw() -> void:
	var half := deck_width / 2.0
	_draw_water_shadow(half)
	_draw_piers(half)
	draw_rect(Rect2(-length, half, length, girder_height), CONCRETE_DARK)
	draw_rect(Rect2(-length, -half, length, deck_width), DECK_COLOR)
	draw_rect(Rect2(-length, -lane_line_width / 2.0, length, lane_line_width), LANE_LINE)
	_draw_rail(-half - rail_width)
	var south_kerb_top := half - rail_width * 0.2
	_draw_rail(south_kerb_top)
	draw_rect(Rect2(-length, half + rail_width * 0.8, length, rail_face_height), CONCRETE_SHADE)
	_draw_railing(-half - rail_width)
	_draw_railing(south_kerb_top)

func _draw_water_shadow(half: float) -> void:
	draw_rect(Rect2(Vector2(-length, -half) + shadow_offset, Vector2(length, deck_width + girder_height)), UiPalette.SHADOW)

func _draw_piers(half: float) -> void:
	var pier_count := int(length / pier_spacing)
	for index in pier_count:
		var center_x := -pier_spacing * (index + 0.5)
		draw_rect(Rect2(center_x - pier_width / 2.0, half + girder_height, pier_width, pier_drop), CONCRETE_SHADE)
		draw_rect(Rect2(center_x + pier_width / 2.0 - 30.0, half + girder_height, 30.0, pier_drop), CONCRETE_DARK)

func _draw_rail(top: float) -> void:
	draw_rect(Rect2(-length, top, length, rail_width), CONCRETE)

func _draw_railing(kerb_top: float) -> void:
	var post_count := int(length / post_spacing) + 1
	for index in post_count:
		var post_x := -post_spacing * index
		draw_rect(Rect2(post_x - post_width / 2.0, kerb_top - post_height, post_width, post_height + rail_width), CONCRETE_SHADE)
		draw_rect(Rect2(post_x + post_width / 2.0 - 10.0, kerb_top - post_height, 10.0, post_height + rail_width), CONCRETE_DARK)
	draw_rect(Rect2(-length, kerb_top - post_height, length, top_rail_thickness), CONCRETE)
