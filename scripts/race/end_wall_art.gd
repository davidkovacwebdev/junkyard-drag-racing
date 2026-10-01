class_name EndWallArt
extends Node2D
## The pile the racers slam into past the finish, drawn over the EndWall's
## collision rectangle. Each venue stacks its own junk, and the stack is
## reshuffled every race so no two walls look alike.

enum Look { CRUSHED_CARS, HAY_BALES, TIRE_STACK, BOULDERS }

@export var look: Look = Look.CRUSHED_CARS

## Squashed car cubes in faded paint, each with its window flattened into one
## glass strip.
const CAR_PAINTS: Array[Color] = [
	Color(0.62, 0.22, 0.18), Color(0.30, 0.40, 0.55), Color(0.30, 0.50, 0.47),
	Color(0.72, 0.58, 0.25), Color(0.40, 0.48, 0.30), Color(0.70, 0.68, 0.63),
	Color(0.45, 0.45, 0.47),
]
const CAR_BALE_HEIGHT := Vector2(80.0, 120.0)
const HAY := Color(0.78, 0.65, 0.36)
const HAY_PALE := Color(0.84, 0.74, 0.46)
const HAY_BALE_HEIGHT := Vector2(56.0, 72.0)
const BOULDER_HEIGHT := Vector2(70.0, 110.0)
const ROCK := Color(0.45, 0.43, 0.41)
const ROCK_PALE := Color(0.53, 0.51, 0.48)
const TIRE_HEIGHT := 38.0
const PAINTED_TIRE := Color(0.62, 0.22, 0.18)
const PAINTED_TIRE_EVERY := 4
## Share of each block's width or height given to its shade strip.
const SHADE_SHARE := 0.22
const SHADE_DARKEN := 0.22
## How far a block may stick out past the wall's sides, so the pile isn't a ruler.
const SIDE_JITTER := 7.0

var _wall_rect: Rect2

func _ready() -> void:
	var shape := get_parent().get_node("CollisionShape2D") as CollisionShape2D
	var wall_size := (shape.shape as RectangleShape2D).size
	_wall_rect = Rect2(shape.position - wall_size * 0.5, wall_size)
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match look:
		Look.CRUSHED_CARS:
			_draw_crushed_cars(rng)
		Look.HAY_BALES:
			_draw_hay_bales(rng)
		Look.TIRE_STACK:
			_draw_tire_stack(rng)
		Look.BOULDERS:
			_draw_boulders(rng)

func _draw_crushed_cars(rng: RandomNumberGenerator) -> void:
	var paints := CAR_PAINTS.duplicate()
	paints.shuffle()
	var bottom := _wall_rect.end.y
	var index := 0
	while bottom > _wall_rect.position.y:
		var height := minf(rng.randf_range(CAR_BALE_HEIGHT.x, CAR_BALE_HEIGHT.y), bottom - _wall_rect.position.y)
		var block := _jittered_block(rng, bottom, height)
		var paint: Color = paints[index % paints.size()]
		draw_colored_polygon(block, paint)
		draw_colored_polygon(_bottom_strip(block, SHADE_SHARE), paint.darkened(SHADE_DARKEN))
		var window_y := lerpf(bottom - height, bottom, rng.randf_range(0.25, 0.4))
		var window_tilt := rng.randf_range(-6.0, 6.0)
		draw_colored_polygon(FlatProps.sliver(
				Vector2(_wall_rect.position.x + 12.0, window_y - window_tilt),
				Vector2(_wall_rect.end.x - 12.0, window_y + window_tilt), height * 0.2), UiPalette.GLASS)
		bottom -= height
		index += 1

func _draw_hay_bales(rng: RandomNumberGenerator) -> void:
	var bottom := _wall_rect.end.y
	var index := 0
	while bottom > _wall_rect.position.y:
		var height := minf(rng.randf_range(HAY_BALE_HEIGHT.x, HAY_BALE_HEIGHT.y), bottom - _wall_rect.position.y)
		var block := _jittered_block(rng, bottom, height)
		var straw := HAY if index % 2 == 0 else HAY_PALE
		draw_colored_polygon(block, straw)
		draw_colored_polygon(_bottom_strip(block, SHADE_SHARE), straw.darkened(SHADE_DARKEN))
		bottom -= height
		index += 1

## Rough rocks piled up, each a lumpy hexagon wider than the wall, in two
## stone tones, with a shade strip.
func _draw_boulders(rng: RandomNumberGenerator) -> void:
	var bottom := _wall_rect.end.y
	var index := 0
	while bottom > _wall_rect.position.y:
		var height := minf(rng.randf_range(BOULDER_HEIGHT.x, BOULDER_HEIGHT.y), bottom - _wall_rect.position.y)
		var block := _jittered_block(rng, bottom, height)
		var bulge := rng.randf_range(10.0, 22.0)
		var rock := PackedVector2Array([
			block[0], block[1], block[1].lerp(block[2], 0.5) + Vector2(bulge, 0.0),
			block[2], block[3], block[3].lerp(block[0], 0.5) - Vector2(bulge, 0.0),
		])
		var stone := ROCK if index % 2 == 0 else ROCK_PALE
		draw_colored_polygon(rock, stone)
		draw_colored_polygon(_bottom_strip(block, SHADE_SHARE), stone.darkened(SHADE_DARKEN))
		bottom -= height
		index += 1

## Side-on tyres in alternating rubber tones, every few painted like a real
## drag strip barrier, with the top tyre's hole showing.
func _draw_tire_stack(rng: RandomNumberGenerator) -> void:
	var painted_offset := rng.randi_range(0, PAINTED_TIRE_EVERY - 1)
	var bottom := _wall_rect.end.y
	var index := 0
	while bottom - TIRE_HEIGHT >= _wall_rect.position.y - 1.0:
		var color := FlatProps.RUBBER_SIDE if index % 2 == 0 else FlatProps.RUBBER_TOP.darkened(0.2)
		if index % PAINTED_TIRE_EVERY == painted_offset:
			color = PAINTED_TIRE
		draw_colored_polygon(_jittered_block(rng, bottom, TIRE_HEIGHT), color)
		bottom -= TIRE_HEIGHT
		index += 1
	var top := Vector2(_wall_rect.get_center().x, bottom)
	var radius := _wall_rect.size.x * 0.5
	draw_colored_polygon(FlatProps.octagon(top, radius, radius * 0.4), FlatProps.RUBBER_TOP)
	draw_colored_polygon(FlatProps.octagon(top, radius * 0.5, radius * 0.2), UiPalette.VOID)

## A block filling the wall's width from `bottom` up by `height`, nudged
## sideways and leaning a little.
func _jittered_block(rng: RandomNumberGenerator, bottom: float, height: float) -> PackedVector2Array:
	var shift := rng.randf_range(-SIDE_JITTER, SIDE_JITTER)
	var lean := rng.randf_range(-SIDE_JITTER, SIDE_JITTER) * 0.5
	var left := _wall_rect.position.x + shift
	var right := _wall_rect.end.x + shift
	return PackedVector2Array([
		Vector2(left + lean, bottom - height), Vector2(right + lean, bottom - height),
		Vector2(right, bottom), Vector2(left, bottom),
	])

## The lowest `share` of a four-cornered block (top-left, top-right,
## bottom-right, bottom-left).
static func _bottom_strip(block: PackedVector2Array, share: float) -> PackedVector2Array:
	return PackedVector2Array([
		block[3].lerp(block[0], share), block[2].lerp(block[1], share), block[2], block[3],
	])
