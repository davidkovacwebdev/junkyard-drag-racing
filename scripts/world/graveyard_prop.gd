@tool
class_name GraveyardProp
extends StaticBody2D
## One piece of the graveyard landmark: a tombstone, a cross, the crypt, a run
## of spiked iron fence, a dead tree or the patch of dead grass under it all.
## Flat polygons, origin on the ground so it Y-sorts against the car (the
## ground's origin is its top-left corner, like FarmProp's yard).

enum Kind { TOMBSTONE, CROSS, CRYPT, IRON_FENCE, DEAD_TREE, GROUND }

@export var kind: Kind = Kind.TOMBSTONE:
	set(value):
		kind = value
		queue_redraw()
## Tombstone and cross: how far it leans, so the rows don't stand to attention.
@export_range(-15.0, 15.0) var lean_degrees: float = 0.0:
	set(value):
		lean_degrees = value
		queue_redraw()
## Iron fence: run length.
@export var length: float = 300.0:
	set(value):
		length = value
		queue_redraw()
## Iron fence only: runs down the screen (into the distance) instead of across it.
@export var vertical: bool = false:
	set(value):
		vertical = value
		queue_redraw()
@export var ground_size: Vector2 = Vector2(700, 460):
	set(value):
		ground_size = value
		queue_redraw()

const STONE := Color(0.56, 0.56, 0.54)
const STONE_SHADE := Color(0.45, 0.45, 0.43)
const SLATE := Color(0.34, 0.34, 0.38)
const MOUND := Color(0.42, 0.35, 0.26)
const DEAD_GRASS := Color(0.46, 0.46, 0.33)
const IRON := Color(0.18, 0.18, 0.2)
const BARK := Color(0.3, 0.26, 0.24)

const FENCE_BAR_SPACING := 46.0
const FENCE_DEPTH_BAR_SPACING := 36.0
const FENCE_HEIGHT := 48.0

func _ready() -> void:
	if not Engine.is_editor_hint() and kind != Kind.GROUND:
		_build_collision()

func _build_collision() -> void:
	var footprint := Rect2()
	match kind:
		Kind.TOMBSTONE, Kind.CROSS:
			footprint = Rect2(-18.0, -8.0, 36.0, 8.0)
		Kind.CRYPT:
			footprint = Rect2(-100.0, -30.0, 200.0, 30.0)
		Kind.IRON_FENCE:
			footprint = Rect2(-4.0, -8.0, 8.0, length + 8.0) if vertical else Rect2(0.0, -8.0, length, 10.0)
		Kind.DEAD_TREE:
			footprint = Rect2(-12.0, -8.0, 24.0, 8.0)
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = footprint.get_center()
	add_child(collision)

func _draw() -> void:
	match kind:
		Kind.TOMBSTONE:
			_draw_tombstone()
		Kind.CROSS:
			_draw_cross()
		Kind.CRYPT:
			_draw_crypt()
		Kind.IRON_FENCE:
			if vertical:
				_draw_depth_fence()
			else:
				_draw_fence()
		Kind.DEAD_TREE:
			_draw_dead_tree()
		Kind.GROUND:
			_draw_ground()

func _draw_mound() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(2.0, 2.0), 26.0, 9.0), MOUND)

func _draw_tombstone() -> void:
	draw_set_transform(Vector2.ZERO, deg_to_rad(lean_degrees), Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18.0, 0.0), Vector2(-18.0, -38.0), Vector2(-10.0, -48.0),
		Vector2(10.0, -48.0), Vector2(18.0, -38.0), Vector2(18.0, 0.0),
	]), STONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10.0, 0.0), Vector2(10.0, -48.0), Vector2(18.0, -38.0), Vector2(18.0, 0.0),
	]), STONE_SHADE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_mound()

func _draw_cross() -> void:
	draw_set_transform(Vector2.ZERO, deg_to_rad(lean_degrees), Vector2.ONE)
	draw_rect(Rect2(-5.0, -60.0, 10.0, 60.0), STONE)
	draw_rect(Rect2(-18.0, -46.0, 36.0, 10.0), STONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_mound()

## A little stone mausoleum: walls, two pale columns, a slate pediment and a
## black doorway.
func _draw_crypt() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-92.0, -10.0), Vector2(106.0, -10.0), Vector2(124.0, 10.0), Vector2(-78.0, 10.0),
	]), UiPalette.SHADOW)
	draw_rect(Rect2(-100.0, -14.0, 200.0, 14.0), STONE_SHADE)
	draw_rect(Rect2(-80.0, -120.0, 160.0, 106.0), STONE)
	draw_rect(Rect2(64.0, -120.0, 16.0, 106.0), STONE_SHADE)
	for column_x: float in [-70.0, 40.0]:
		draw_rect(Rect2(column_x, -120.0, 16.0, 106.0), STONE.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-96.0, -116.0), Vector2(0.0, -168.0), Vector2(96.0, -116.0),
	]), SLATE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24.0, -14.0), Vector2(-24.0, -70.0), Vector2(-12.0, -84.0),
		Vector2(12.0, -84.0), Vector2(24.0, -70.0), Vector2(24.0, -14.0),
	]), UiPalette.VOID)

func _fence_bar(base: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		base + Vector2(-3.0, 0.0), base + Vector2(-3.0, -FENCE_HEIGHT + 8.0), base + Vector2(0.0, -FENCE_HEIGHT),
		base + Vector2(3.0, -FENCE_HEIGHT + 8.0), base + Vector2(3.0, 0.0),
	])

func _draw_fence() -> void:
	for rail_y: float in [-36.0, -12.0]:
		draw_rect(Rect2(0.0, rail_y, length, 5.0), IRON)
	var bars := maxi(1, roundi(length / FENCE_BAR_SPACING))
	for i in bars + 1:
		draw_colored_polygon(_fence_bar(Vector2(length * i / bars, 0.0)), IRON)

func _draw_depth_fence() -> void:
	for rail_y: float in [-36.0, -12.0]:
		draw_rect(Rect2(-2.0, rail_y, 4.0, length), IRON)
	var bars := maxi(1, roundi(length / FENCE_DEPTH_BAR_SPACING))
	for i in bars + 1:
		draw_colored_polygon(_fence_bar(Vector2(0.0, length * i / bars)), IRON)

## A bare, crooked tree: a leaning trunk and three chunky branches.
func _draw_dead_tree() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(6.0, 0.0), 30.0, 7.0), UiPalette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12.0, 0.0), Vector2(-8.0, -116.0), Vector2(0.0, -116.0), Vector2(12.0, 0.0),
	]), BARK)
	draw_colored_polygon(FlatProps.sliver(Vector2(-6.0, -70.0), Vector2(-46.0, -116.0), 9.0), BARK)
	draw_colored_polygon(FlatProps.sliver(Vector2(-4.0, -96.0), Vector2(34.0, -136.0), 8.0), BARK)
	draw_colored_polygon(FlatProps.sliver(Vector2(-4.0, -112.0), Vector2(-14.0, -156.0), 7.0), BARK)

## Dead grass with a few bare dirt patches. Drawn only below and right of the
## origin so it stays under everything it Y-sorts with.
func _draw_ground() -> void:
	var w := ground_size.x
	var h := ground_size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.04, h * 0.06), Vector2(w * 0.5, 0.0), Vector2(w * 0.96, h * 0.04), Vector2(w, h * 0.6),
		Vector2(w * 0.92, h), Vector2(w * 0.3, h * 0.97), Vector2(0.0, h * 0.85), Vector2(w * 0.02, h * 0.35),
	]), DEAD_GRASS)
	for patch in [Rect2(w * 0.15, h * 0.62, 80.0, 18.0), Rect2(w * 0.7, h * 0.4, 90.0, 16.0), Rect2(w * 0.45, h * 0.85, 70.0, 14.0)]:
		draw_colored_polygon(FlatProps.octagon(patch.get_center(), patch.size.x / 2.0, patch.size.y / 2.0), MOUND)
