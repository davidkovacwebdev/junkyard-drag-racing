@tool
class_name BridgeBarricade
extends StaticBody2D
## The roadblock that keeps the car off the bridge, GTA style: concrete blocks
## at both kerbs, a striped bar between them and a red "closed" sign standing
## on top. The origin is the middle of the deck; the bar runs along Y.

const BAR_ORANGE := Color(0.85, 0.45, 0.12)
const BAR_STRIPE := UiPalette.TRIM_OFF_WHITE
const BLOCK := Color(0.62, 0.6, 0.55)
const BLOCK_SHADE := Color(0.49, 0.47, 0.43)

@export var deck_width: float = 216.0
@export var wall_overhang: float = 70.0
@export var bar_thickness: float = 34.0
@export var block_size: Vector2 = Vector2(70.0, 80.0)
@export var sign_size: Vector2 = Vector2(120.0, 90.0)
@export var sign_height: float = 150.0

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(block_size.x, deck_width + wall_overhang * 2.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _draw() -> void:
	var half := deck_width / 2.0 + wall_overhang
	draw_rect(Rect2(block_size.x / 2.0, -half + 14.0, block_size.x * 0.5, half * 2.0), UiPalette.SHADOW)
	for side: float in [-1.0, 1.0]:
		var block_top: float = side * half - (block_size.y if side > 0.0 else 0.0)
		draw_rect(Rect2(-block_size.x / 2.0, block_top, block_size.x, block_size.y), BLOCK)
		draw_rect(Rect2(block_size.x / 2.0 - 18.0, block_top, 18.0, block_size.y), BLOCK_SHADE)
	var bar_length := half * 2.0 - block_size.y * 2.0
	draw_rect(Rect2(-bar_thickness / 2.0, -bar_length / 2.0, bar_thickness, bar_length), BAR_ORANGE)
	for stripe_y in [-bar_length * 0.25, bar_length * 0.25]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-bar_thickness / 2.0, stripe_y - 30.0), Vector2(bar_thickness / 2.0, stripe_y - 6.0),
			Vector2(bar_thickness / 2.0, stripe_y + 30.0), Vector2(-bar_thickness / 2.0, stripe_y + 6.0),
		]), BAR_STRIPE)
	var post_base_y := -half + block_size.y / 2.0
	var sign_top := post_base_y - sign_height
	draw_rect(Rect2(-8.0, sign_top, 16.0, sign_height), UiPalette.METAL_GREY)
	draw_rect(Rect2(-sign_size.x / 2.0, sign_top - sign_size.y, sign_size.x, sign_size.y), UiPalette.DANGER_RED)
	draw_rect(Rect2(-sign_size.x * 0.32, sign_top - sign_size.y / 2.0 - 8.0, sign_size.x * 0.64, 16.0), UiPalette.TRIM_OFF_WHITE)
