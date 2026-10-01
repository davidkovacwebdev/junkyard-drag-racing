@tool
class_name OilFieldProp
extends StaticBody2D
## One piece of the oil field landmark besides the pumpjacks (see OilPump): a
## storage tank, a huddle of oil drums or the oily ground under it all. Flat
## polygons, origin on the ground so it Y-sorts against the car (the pad's
## origin is its top-left corner, like FarmProp's yard).

enum Kind { TANK, DRUMS, PAD }

@export var kind: Kind = Kind.TANK:
	set(value):
		kind = value
		queue_redraw()
@export var pad_size: Vector2 = Vector2(900, 500):
	set(value):
		pad_size = value
		queue_redraw()

const TANK_STEEL := Color(0.5, 0.48, 0.44)
const DRUM_COLORS: Array[Color] = [Color(0.2, 0.3, 0.42), Color(0.55, 0.22, 0.16), Color(0.2, 0.3, 0.42)]
const OILY_SAND := Color(0.56, 0.47, 0.34)
const OIL := Color(0.2, 0.18, 0.17)

const TANK_RADIUS := 70.0
const TANK_HEIGHT := 130.0

func _ready() -> void:
	if not Engine.is_editor_hint() and kind != Kind.PAD:
		_build_collision()

func _build_collision() -> void:
	var footprint := Rect2(-TANK_RADIUS, -20.0, TANK_RADIUS * 2.0, 20.0) if kind == Kind.TANK else Rect2(-40.0, -12.0, 80.0, 12.0)
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = footprint.get_center()
	add_child(collision)

func _draw() -> void:
	match kind:
		Kind.TANK:
			_draw_tank()
		Kind.DRUMS:
			_draw_drums()
		Kind.PAD:
			_draw_pad()

## A squat storage tank: one steel drum of a thing with a lighter lid.
func _draw_tank() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(10.0, 0.0), TANK_RADIUS + 14.0, 18.0), UiPalette.SHADOW)
	draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, TANK_RADIUS, 16.0), TANK_STEEL)
	draw_rect(Rect2(-TANK_RADIUS, -TANK_HEIGHT, TANK_RADIUS * 2.0, TANK_HEIGHT), TANK_STEEL)
	draw_rect(Rect2(TANK_RADIUS - 26.0, -TANK_HEIGHT, 26.0, TANK_HEIGHT), TANK_STEEL.darkened(0.2))
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -TANK_HEIGHT), TANK_RADIUS, 22.0), TANK_STEEL.lightened(0.15))

func _draw_drums() -> void:
	FlatProps.draw_drum(self, Vector2(-22.0, -6.0), DRUM_COLORS[0])
	FlatProps.draw_drum(self, Vector2(10.0, -10.0), DRUM_COLORS[1])
	FlatProps.draw_drum(self, Vector2(-4.0, 6.0), DRUM_COLORS[2])

## Trampled sandy ground with a few black oil slicks soaked into it. Drawn only
## below and right of the origin so it stays under everything it Y-sorts with.
func _draw_pad() -> void:
	var w := pad_size.x
	var h := pad_size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.06, h * 0.04), Vector2(w * 0.5, 0.0), Vector2(w * 0.95, h * 0.06), Vector2(w, h * 0.55),
		Vector2(w * 0.9, h), Vector2(w * 0.35, h * 0.96), Vector2(0.0, h * 0.8), Vector2(w * 0.02, h * 0.3),
	]), OILY_SAND)
	for slick in [Rect2(w * 0.2, h * 0.45, 90.0, 22.0), Rect2(w * 0.62, h * 0.3, 70.0, 18.0), Rect2(w * 0.5, h * 0.78, 110.0, 24.0)]:
		draw_colored_polygon(FlatProps.octagon(slick.get_center(), slick.size.x / 2.0, slick.size.y / 2.0), OIL)
