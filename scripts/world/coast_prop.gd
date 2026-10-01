@tool
class_name CoastProp
extends StaticBody2D
## One piece of the seaside landmarks (the fishing port and the lighthouse
## point): a wooden pier, a fishing boat bobbing at anchor, the fish shack, a
## stack of fish crates or a shore boulder. Flat polygons, origin on the ground
## (the boat's is its waterline) so it Y-sorts against the car. The pier and the
## boat sit out on the water and have no collision.

enum Kind { PIER, BOAT, SHACK, FISH_CRATES, ROCK }

@export var kind: Kind = Kind.PIER:
	set(value):
		kind = value
		queue_redraw()
## Pier only: how far it runs out to sea (to the right).
@export var length: float = 480.0:
	set(value):
		length = value
		queue_redraw()
## Boat only: offsets the bob so neighbouring boats don't rock in step.
@export var bob_phase: float = 0.0
## Boat only: points the bow left instead of right.
@export var flipped: bool = false:
	set(value):
		flipped = value
		queue_redraw()

const WOOD := Color(0.5, 0.36, 0.22)
const WOOD_LIGHT := Color(0.6, 0.44, 0.27)
const WOOD_DARK := Color(0.34, 0.24, 0.15)
const HULL := Color(0.6, 0.24, 0.18)
const SEA := Color("3a7c9a")
const SHACK_WALL := Color(0.36, 0.46, 0.5)
const TIN := Color(0.52, 0.54, 0.56)
const FISH := Color(0.86, 0.52, 0.2)
const FISH_SILVER := Color(0.68, 0.72, 0.74)
const STONE := Color(0.5, 0.5, 0.48)
const GULL := Color(0.88, 0.88, 0.84)

const DECK_DEPTH := 56.0
const DECK_FACE := 12.0
const PILING_DROP := 28.0
const PILING_SPACING := 110.0
const BOB_SPEED := 1.6
const BOB_HEIGHT := 4.0
const ROCK_DEGREES := 2.5

var _time := 0.0

func _ready() -> void:
	set_process(kind == Kind.BOAT)
	if not Engine.is_editor_hint():
		_build_collision()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _build_collision() -> void:
	var footprint := Rect2()
	match kind:
		Kind.SHACK:
			footprint = Rect2(-100.0, -30.0, 200.0, 30.0)
		Kind.FISH_CRATES:
			footprint = Rect2(-34.0, -12.0, 68.0, 12.0)
		Kind.ROCK:
			footprint = Rect2(-40.0, -14.0, 80.0, 14.0)
		_:
			return
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = footprint.get_center()
	add_child(collision)

func _draw() -> void:
	match kind:
		Kind.PIER:
			_draw_pier()
		Kind.BOAT:
			_draw_boat()
		Kind.SHACK:
			_draw_shack()
		Kind.FISH_CRATES:
			_draw_fish_crates()
		Kind.ROCK:
			_draw_rock()

## The deck runs right from the origin, its front face standing on pilings that
## go down into the water. A gull stands near the far end (the port's one gag).
func _draw_pier() -> void:
	var pilings := maxi(2, roundi(length / PILING_SPACING))
	for i in pilings:
		var x := 14.0 + (length - 28.0) * i / (pilings - 1)
		draw_rect(Rect2(x - 6.0, -4.0, 12.0, PILING_DROP), WOOD_DARK)
	draw_rect(Rect2(0.0, -DECK_FACE - DECK_DEPTH, length, DECK_DEPTH), WOOD_LIGHT)
	draw_rect(Rect2(0.0, -DECK_FACE, length, DECK_FACE), WOOD)
	var gull := Vector2(length - 50.0, -DECK_FACE - 18.0)
	draw_colored_polygon(FlatProps.octagon(gull + Vector2(0.0, -14.0), 20.0, 14.0), GULL)
	draw_colored_polygon(FlatProps.octagon(gull + Vector2(-16.0, -30.0), 9.0, 9.0), GULL)
	draw_colored_polygon(PackedVector2Array([
		gull + Vector2(-8.0, -22.0), gull + Vector2(18.0, -18.0), gull + Vector2(30.0, -8.0), gull + Vector2(0.0, -8.0),
	]), STONE)

## A little fishing boat: red hull, white wheelhouse with one dark window and a
## stubby mast. It bobs and rocks; the band of sea over the hull's foot stays
## put, so the boat reads as sitting in the water.
func _draw_boat() -> void:
	var bob := sin(_time * BOB_SPEED + bob_phase) * BOB_HEIGHT
	var rock := deg_to_rad(sin(_time * BOB_SPEED * 0.7 + bob_phase) * ROCK_DEGREES)
	var facing := Vector2(-1.0 if flipped else 1.0, 1.0)
	draw_set_transform(Vector2(0.0, bob), rock, facing)
	draw_colored_polygon(FlatProps.sliver(Vector2(22.0, -40.0), Vector2(26.0, -124.0), 6.0), UiPalette.METAL_GREY)
	draw_rect(Rect2(-52.0, -78.0, 50.0, 42.0), UiPalette.TRIM_OFF_WHITE)
	draw_rect(Rect2(-12.0, -78.0, 10.0, 42.0), UiPalette.TRIM_OFF_WHITE.darkened(0.2))
	draw_rect(Rect2(-42.0, -70.0, 22.0, 14.0), UiPalette.INK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-72.0, -36.0), Vector2(80.0, -44.0), Vector2(62.0, 4.0), Vector2(-60.0, 4.0),
	]), HULL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-82.0, -6.0), Vector2(86.0, -8.0), Vector2(84.0, 8.0), Vector2(-80.0, 8.0),
	]), SEA)

## The fish shack: a weathered blue plank hut under a tin lean-to, with a big
## orange fish nailed over the wall as its sign.
func _draw_shack() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-92.0, -10.0), Vector2(106.0, -10.0), Vector2(124.0, 10.0), Vector2(-78.0, 10.0),
	]), UiPalette.SHADOW)
	draw_rect(Rect2(-100.0, -118.0, 200.0, 118.0), SHACK_WALL)
	draw_rect(Rect2(84.0, -118.0, 16.0, 118.0), SHACK_WALL.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-114.0, -148.0), Vector2(114.0, -124.0), Vector2(114.0, -112.0), Vector2(-114.0, -112.0),
	]), TIN)
	draw_rect(Rect2(24.0, -70.0, 40.0, 70.0), UiPalette.VOID)
	var fish := Vector2(-40.0, -74.0)
	draw_colored_polygon(PackedVector2Array([
		fish + Vector2(-38.0, 0.0), fish + Vector2(-20.0, -16.0), fish + Vector2(18.0, -14.0),
		fish + Vector2(30.0, 0.0), fish + Vector2(18.0, 14.0), fish + Vector2(-20.0, 16.0),
	]), FISH)
	draw_colored_polygon(PackedVector2Array([
		fish + Vector2(26.0, 0.0), fish + Vector2(46.0, -18.0), fish + Vector2(42.0, 0.0), fish + Vector2(46.0, 18.0),
	]), FISH.darkened(0.2))

## Two wooden crates, the top one heaped with fish tails poking out.
func _draw_fish_crates() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 40.0, 7.0), UiPalette.SHADOW)
	draw_rect(Rect2(-34.0, -30.0, 52.0, 30.0), WOOD_LIGHT)
	draw_rect(Rect2(10.0, -30.0, 8.0, 30.0), WOOD)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24.0, -56.0), Vector2(-16.0, -68.0), Vector2(-12.0, -58.0), Vector2(-2.0, -72.0),
		Vector2(2.0, -58.0), Vector2(10.0, -66.0), Vector2(12.0, -54.0),
	]), FISH_SILVER)
	draw_rect(Rect2(-28.0, -56.0, 44.0, 26.0), WOOD)

func _draw_rock() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(6.0, 0.0), 46.0, 8.0), UiPalette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-42.0, 0.0), Vector2(-36.0, -30.0), Vector2(-12.0, -48.0), Vector2(18.0, -44.0),
		Vector2(40.0, -22.0), Vector2(44.0, 0.0),
	]), STONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(14.0, 0.0), Vector2(22.0, -26.0), Vector2(40.0, -22.0), Vector2(44.0, 0.0),
	]), STONE.darkened(0.2))
