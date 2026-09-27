class_name TrackHazards
extends RefCounted
## Random junk scattered over the drag strip each race: rocks on some races, and
## puddles when it's raining. They're drawn on a static layer across the whole
## track, not on any lane, so a car only hits one if its drawn (steered) position
## runs over it — see single_lane_race_setup.gd, which decides the hits.

const ROCKY_RACE_CHANCE := 0.6
const ROCK_COUNT_RANGE := Vector2i(10, 18)
const PUDDLE_COUNT_RANGE := Vector2i(6, 12)
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

## A rock drawn once on the track, plus an invisible physical copy of it on every
## lane's real road. A copy stays ghostly until that lane's car is decided to be
## running over the drawn rock; then it turns solid for that lane only.
class Rock:
	## Where the rock is drawn: the middle of its base.
	var position: Vector2
	var half_width: float
	var colliders: Array[StaticBody2D] = []
	var lane_layers: Array[int] = []
	var decided: Array[bool] = []

	func left_x() -> float:
		return position.x - half_width

	func decide(lane: int, solid: bool) -> void:
		decided[lane] = true
		if solid:
			colliders[lane].collision_layer = lane_layers[lane]

class Puddle:
	var center: Vector2
	var radii: Vector2

	func covers(point: Vector2) -> bool:
		var relative := (point - center) / radii
		return relative.length_squared() <= 1.0

## Rocks anywhere in `band` (the drawn track's y range) between the start and
## the finish. `lane_surfaces` and `lane_layers` are each lane's real road height
## and collision bit, in lane order.
static func add_rocks(parent: Node, band: Vector2, lane_surfaces: Array[float], lane_layers: Array[int]) -> Array[Rock]:
	var rocks: Array[Rock] = []
	for i in randi_range(ROCK_COUNT_RANGE.x, ROCK_COUNT_RANGE.y):
		var outline := _rock_outline()
		var rock := Rock.new()
		rock.position = Vector2(randf_range(FIRST_HAZARD_X, LAST_HAZARD_X), randf_range(band.x, band.y))
		rock.half_width = outline[0].x * -1.0
		var art := _polygon(outline, ROCK_COLOR)
		art.name = "Rock"
		parent.add_child(art)
		art.global_position = rock.position
		for lane in lane_surfaces.size():
			var collider := _rock_collider(outline, lane_layers[lane])
			parent.add_child(collider)
			collider.global_position = Vector2(rock.position.x, lane_surfaces[lane])
			rock.colliders.append(collider)
			rock.lane_layers.append(lane_layers[lane])
			rock.decided.append(false)
		rocks.append(rock)
	return rocks

static func add_puddles(parent: Node, band: Vector2) -> Array[Puddle]:
	var puddles: Array[Puddle] = []
	for i in randi_range(PUDDLE_COUNT_RANGE.x, PUDDLE_COUNT_RANGE.y):
		var radius := randf_range(PUDDLE_WIDTH_RANGE.x, PUDDLE_WIDTH_RANGE.y) * 0.5
		var squish := randf_range(PUDDLE_SQUISH_RANGE.x, PUDDLE_SQUISH_RANGE.y)
		var puddle := Puddle.new()
		puddle.center = Vector2(randf_range(FIRST_HAZARD_X, LAST_HAZARD_X), randf_range(band.x, band.y))
		puddle.radii = Vector2(radius, radius * squish)
		var art := _build_puddle(radius, squish)
		parent.add_child(art)
		art.global_position = puddle.center
		puddles.append(puddle)
	return puddles

## A lumpy half-dome, low enough for any wheel to climb over. Starts left to
## right along the base, so outline[0] is the left edge.
static func _rock_outline() -> PackedVector2Array:
	var width := randf_range(ROCK_WIDTH_RANGE.x, ROCK_WIDTH_RANGE.y)
	var height := randf_range(ROCK_HEIGHT_RANGE.x, ROCK_HEIGHT_RANGE.y)
	var outline := PackedVector2Array()
	for i in ROCK_OUTLINE_POINTS + 1:
		var angle := PI * float(i) / float(ROCK_OUTLINE_POINTS)
		var lumpiness := 1.0 if i == 0 or i == ROCK_OUTLINE_POINTS else randf_range(0.8, 1.1)
		outline.append(Vector2(-cos(angle) * width * 0.5, -sin(angle) * height * lumpiness))
	return outline

## One lane's invisible copy of a rock, not solid to anything until Rock.decide()
## arms it. Clacks when a wheel or body rolls onto it while armed.
static func _rock_collider(outline: PackedVector2Array, lane_layer: int) -> StaticBody2D:
	var collider := StaticBody2D.new()
	collider.name = "RockCollider"
	collider.collision_layer = 0
	collider.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = outline
	collider.add_child(shape)

	var trigger := Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = lane_layer
	var trigger_shape := CollisionPolygon2D.new()
	trigger_shape.polygon = _scaled(outline, Vector2(1.3, 1.6), Vector2.ZERO)
	trigger.add_child(trigger_shape)
	collider.add_child(trigger)
	trigger.body_entered.connect(func(body: Node2D) -> void:
		if collider.collision_layer != 0 and (body is CarWheel or body is CarBody):
			RaceCarAudio.play(collider, &"rock_clack", collider.global_position, -4.0))
	return collider

## A lumpy pool of standing water: a deeper middle, a streak of reflected sky, a
## glint, and a few stray drops around the edge.
static func _build_puddle(radius: float, squish: float) -> Node2D:
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
