@tool
class_name ForgeProp
extends StaticBody2D
## One piece of the scrap forge landmark: the anvil on its stump, the quench
## barrel, a heap of scrap waiting to be melted, or the sooty concrete pad under
## it all. Flat polygons, origin on the ground so it Y-sorts against the car
## (the pad's origin is its top-left corner, like FarmProp's yard).

enum Kind { ANVIL, QUENCH_BARREL, SCRAP_HEAP, PAD }

@export var kind: Kind = Kind.ANVIL:
	set(value):
		kind = value
		queue_redraw()
@export var pad_size: Vector2 = Vector2(700, 380):
	set(value):
		pad_size = value
		queue_redraw()

const STUMP := Color(0.45, 0.32, 0.2)
const STUMP_DARK := Color(0.36, 0.25, 0.15)
const IRON := Color(0.26, 0.26, 0.28)
const IRON_LIGHT := Color(0.38, 0.38, 0.4)
const WATER := Color(0.3, 0.42, 0.46)
const CONCRETE := Color(0.5, 0.49, 0.46)
const CONCRETE_DARK := Color(0.44, 0.43, 0.4)
const SOOT := Color(0.3, 0.29, 0.28)
const _SCRAP_COLORS: Array[Color] = [
	Color(0.45, 0.4, 0.35), Color(0.55, 0.3, 0.2), Color(0.3, 0.3, 0.32),
	Color(0.6, 0.5, 0.2), Color(0.5, 0.15, 0.15), Color(0.64, 0.68, 0.74),
]

func _ready() -> void:
	if not Engine.is_editor_hint() and kind != Kind.PAD:
		_build_collision()

func _build_collision() -> void:
	var footprint := Rect2()
	match kind:
		Kind.ANVIL:
			footprint = Rect2(-24.0, -12.0, 48.0, 12.0)
		Kind.QUENCH_BARREL:
			footprint = Rect2(-22.0, -12.0, 44.0, 12.0)
		Kind.SCRAP_HEAP:
			footprint = Rect2(-60.0, -18.0, 120.0, 18.0)
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = footprint.get_center()
	add_child(collision)

func _draw() -> void:
	match kind:
		Kind.ANVIL:
			_draw_anvil()
		Kind.QUENCH_BARREL:
			_draw_barrel()
		Kind.SCRAP_HEAP:
			_draw_heap()
		Kind.PAD:
			_draw_pad()

func _draw_anvil() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 30.0, 8.0), UiPalette.SHADOW)
	draw_rect(Rect2(-18.0, -30.0, 36.0, 30.0), STUMP)
	draw_rect(Rect2(8.0, -30.0, 10.0, 30.0), STUMP_DARK)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -30.0), 18.0, 5.0), STUMP.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10.0, -34.0), Vector2(10.0, -34.0), Vector2(14.0, -44.0), Vector2(-14.0, -44.0),
	]), IRON)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34.0, -52.0), Vector2(-22.0, -56.0), Vector2(26.0, -56.0), Vector2(26.0, -44.0),
		Vector2(-16.0, -44.0),
	]), IRON)
	draw_rect(Rect2(-18.0, -56.0, 40.0, 3.0), IRON_LIGHT)
	draw_rect(Rect2(-2.0, -66.0, 4.0, 10.0), STUMP_DARK)
	draw_rect(Rect2(-9.0, -72.0, 18.0, 7.0), IRON)

func _draw_barrel() -> void:
	FlatProps.draw_drum(self, Vector2.ZERO, UiPalette.RUST.darkened(0.1), 18.0, 36.0)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -36.0), 14.0, 4.0), WATER)
	draw_colored_polygon(FlatProps.octagon(Vector2(-4.0, -37.0), 5.0, 1.5), WATER.lightened(0.3))

func _draw_heap() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(6.0, 0.0), 70.0, 14.0), UiPalette.SHADOW)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in 16:
		var center := Vector2(rng.randf_range(-50.0, 50.0), -rng.randf_range(4.0, 40.0) * (1.0 - absf(float(i % 8) - 3.5) / 5.0))
		var points := PackedVector2Array()
		var corners := rng.randi_range(3, 5)
		var radius := rng.randf_range(8.0, 18.0)
		var spin := rng.randf() * TAU
		for k in corners:
			points.append(center + Vector2.from_angle(spin + TAU * k / corners) * radius * rng.randf_range(0.6, 1.1))
		draw_colored_polygon(points, _SCRAP_COLORS[rng.randi() % _SCRAP_COLORS.size()])
	FlatProps.draw_tire_stack(self, Vector2(-44.0, 0.0), 2, 14.0, 8.0)

func _draw_pad() -> void:
	var w := pad_size.x
	var h := pad_size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.04, h * 0.02), Vector2(w * 0.96, 0.0), Vector2(w, h * 0.5), Vector2(w * 0.97, h),
		Vector2(w * 0.05, h * 0.98), Vector2(0.0, h * 0.45),
	]), CONCRETE)
	for crack in [[Vector2(w * 0.2, h * 0.2), Vector2(w * 0.32, h * 0.44)], [Vector2(w * 0.7, h * 0.7), Vector2(w * 0.86, h * 0.62)]]:
		draw_colored_polygon(FlatProps.sliver(crack[0], crack[1], 3.0), CONCRETE_DARK)
	for patch in [Rect2(w * 0.4, h * 0.35, 140.0, 40.0), Rect2(w * 0.12, h * 0.7, 90.0, 24.0)]:
		draw_colored_polygon(FlatProps.octagon(patch.get_center(), patch.size.x / 2.0, patch.size.y / 2.0), SOOT)
