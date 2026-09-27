class_name TrackHazards
extends RefCounted
## Random junk dropped on the drag strip's lanes each race: rocks to bounce
## over on some races, and puddles when it's raining that cost a car speed
## (single_lane_race_setup.gd does the slowing).

const ROCKY_RACE_CHANCE := 0.6
const MAX_ROCKS_PER_LANE := 3
const MIN_PUDDLES_PER_LANE := 1
const MAX_PUDDLES_PER_LANE := 3
## Hazards stay clear of the start drop and the finish line.
const FIRST_HAZARD_X := 700.0
const LAST_HAZARD_X := 5100.0

const ROCK_WIDTH_RANGE := Vector2(22.0, 40.0)
const ROCK_HEIGHT_RANGE := Vector2(7.0, 14.0)
const ROCK_OUTLINE_POINTS := 8
const ROCK_COLOR := Color(0.46, 0.43, 0.40, 1.0)

const PUDDLE_WIDTH_RANGE := Vector2(140.0, 260.0)
## Puddle height as a share of its width: seen from above at the track's angle.
const PUDDLE_SQUISH_RANGE := Vector2(0.35, 0.5)
const PUDDLE_OUTLINE_POINTS := 28
## Same water as the overworld puddles: lighter than the asphalt, so it reads
## as water rather than a hole.
const PUDDLE_COLOR := Color(0.29, 0.52, 0.62, 0.85)
const PUDDLE_DEEP_COLOR := Color(0.2, 0.4, 0.52, 0.9)
const PUDDLE_SKY_COLOR := Color(0.62, 0.8, 0.9, 0.55)
const PUDDLE_GLINT_COLOR := Color(1.0, 1.0, 1.0, 0.45)

class Puddle:
	var node: Node2D
	var from_x: float
	var to_x: float

	func covers(x: float) -> bool:
		return x >= from_x and x <= to_x

## Up to MAX_ROCKS_PER_LANE rocks sitting on a lane's road at `surface_y`, solid
## only to cars on `lane_layer`.
static func add_rocks(parent: Node, surface_y: float, lane_layer: int) -> Array[StaticBody2D]:
	var rocks: Array[StaticBody2D] = []
	for i in randi_range(0, MAX_ROCKS_PER_LANE):
		var rock := _build_rock(lane_layer)
		parent.add_child(rock)
		rock.global_position = Vector2(randf_range(FIRST_HAZARD_X, LAST_HAZARD_X), surface_y)
		rocks.append(rock)
	return rocks

static func add_puddles(parent: Node, surface_y: float) -> Array[Puddle]:
	var puddles: Array[Puddle] = []
	for i in randi_range(MIN_PUDDLES_PER_LANE, MAX_PUDDLES_PER_LANE):
		var width := randf_range(PUDDLE_WIDTH_RANGE.x, PUDDLE_WIDTH_RANGE.y)
		var puddle := Puddle.new()
		puddle.node = _build_puddle(width)
		parent.add_child(puddle.node)
		var center_x := randf_range(FIRST_HAZARD_X, LAST_HAZARD_X)
		puddle.node.global_position = Vector2(center_x, surface_y)
		puddle.from_x = center_x - width * 0.5
		puddle.to_x = center_x + width * 0.5
		puddles.append(puddle)
	return puddles

## A lumpy half-dome, low enough for any wheel to climb over, with an Area2D
## just outside it that clacks when a wheel or body rolls onto it.
static func _build_rock(lane_layer: int) -> StaticBody2D:
	var width := randf_range(ROCK_WIDTH_RANGE.x, ROCK_WIDTH_RANGE.y)
	var height := randf_range(ROCK_HEIGHT_RANGE.x, ROCK_HEIGHT_RANGE.y)
	var outline := PackedVector2Array()
	for i in ROCK_OUTLINE_POINTS + 1:
		var angle := PI * float(i) / float(ROCK_OUTLINE_POINTS)
		var lumpiness := 1.0 if i == 0 or i == ROCK_OUTLINE_POINTS else randf_range(0.8, 1.1)
		outline.append(Vector2(-cos(angle) * width * 0.5, -sin(angle) * height * lumpiness))

	var rock := StaticBody2D.new()
	rock.name = "Rock"
	rock.collision_layer = lane_layer
	rock.collision_mask = 0
	var collision := CollisionPolygon2D.new()
	collision.polygon = outline
	rock.add_child(collision)
	rock.add_child(_polygon(outline, ROCK_COLOR))

	var trigger := Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = lane_layer
	var trigger_shape := CollisionPolygon2D.new()
	trigger_shape.polygon = _scaled(outline, Vector2(1.3, 1.6), Vector2.ZERO)
	trigger.add_child(trigger_shape)
	rock.add_child(trigger)
	trigger.body_entered.connect(func(body: Node2D) -> void:
		if body is CarWheel or body is CarBody:
			RaceCarAudio.play(rock, &"rock_clack", rock.global_position, -4.0))
	return rock

## A lumpy pool of standing water centred on the road line, so the wheels are
## drawn rolling through it: a deeper middle, a streak of reflected sky, a glint,
## and a few stray drops around the edge.
static func _build_puddle(width: float) -> Node2D:
	var radius := width * 0.5
	var squish := randf_range(PUDDLE_SQUISH_RANGE.x, PUDDLE_SQUISH_RANGE.y)
	var outline := _blob(radius, squish)
	var puddle := Node2D.new()
	puddle.name = "Puddle"
	puddle.add_child(_polygon(outline, PUDDLE_COLOR))
	puddle.add_child(_polygon(_scaled(outline, Vector2(0.72, 0.68), Vector2(radius * 0.06, radius * squish * 0.08)), PUDDLE_DEEP_COLOR))
	puddle.add_child(_polygon(_scaled(outline, Vector2(0.45, 0.16), Vector2(-radius * 0.2, -radius * squish * 0.3)), PUDDLE_SKY_COLOR))
	puddle.add_child(_polygon(_scaled(outline, Vector2(0.08, 0.1), Vector2(radius * 0.35, -radius * squish * 0.35)), PUDDLE_GLINT_COLOR))
	for i in randi_range(2, 5):
		var angle := randf_range(0.0, TAU)
		var distance := radius * randf_range(1.08, 1.3)
		var drop_radius := randf_range(4.0, 9.0)
		var drop := _scaled(_blob(drop_radius, squish), Vector2.ONE, Vector2(cos(angle) * distance, sin(angle) * distance * squish))
		puddle.add_child(_polygon(drop, PUDDLE_COLOR))
	return puddle

## An irregular squashed ellipse: a couple of lobes plus jitter, so it reads as
## a spill rather than a perfect oval.
static func _blob(radius: float, squish: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	var phase_a := randf_range(0.0, TAU)
	var phase_b := randf_range(0.0, TAU)
	for i in PUDDLE_OUTLINE_POINTS:
		var angle := TAU * float(i) / float(PUDDLE_OUTLINE_POINTS)
		var lobes := 1.0 + 0.12 * sin(angle * 3.0 + phase_a) + 0.07 * sin(angle * 5.0 + phase_b) + randf_range(-0.03, 0.03)
		outline.append(Vector2(cos(angle), sin(angle) * squish) * radius * lobes)
	return outline

static func _polygon(outline: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = outline
	polygon.color = color
	return polygon

static func _scaled(outline: PackedVector2Array, scale: Vector2, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in outline:
		result.append(point * scale + offset)
	return result
