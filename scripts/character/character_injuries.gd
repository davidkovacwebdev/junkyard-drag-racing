class_name CharacterInjuries
extends RefCounted
## Bruises and blood for a character who just ate a spike pit: chunky flat
## polygons stuck on over the face, in the shared character space (origin
## at the feet, eyes around y -217, every head inside x ±19 at eye height).
##
##   level 1: a black eye, a bloody nose, a cut on the cheek
##   level 2: both eyes black, the cut bleeding down the cheek, and a blood
##            stain on the shirt
##
## Put on a CutsceneActor with `apply()`; the actor is freed with the scene,
## so nothing has to take them off again.

const BRUISE := Color(0.42, 0.3, 0.46, 1)
const BLOOD := Color(0.66, 0.1, 0.1, 1)
## Bruises sit over the skull (z 3) but under the eyes (z 5); blood goes on
## top of everything, beards and goggles included.
const BRUISE_Z := 4
const BLOOD_Z := 7

const BLACK_EYE_LEFT := [Vector2(-24, -216), Vector2(-18, -229), Vector2(-4, -229),
		Vector2(0, -217), Vector2(-5, -205), Vector2(-19, -204)]
const NOSE_BLOOD := [Vector2(-3, -210), Vector2(4, -209), Vector2(5, -191), Vector2(8, -184),
		Vector2(2, -179), Vector2(-3, -185)]
## On the cheek, not the forehead, so hats, goggles and fringes never hide it.
const GASH := [Vector2(8, -203), Vector2(20, -207), Vector2(21, -201), Vector2(9, -197)]
## Level 2's gash, bleeding on down the cheek.
const GASH_DRIP := [Vector2(8, -203), Vector2(20, -207), Vector2(21, -201), Vector2(17, -199),
		Vector2(17, -190), Vector2(12, -188), Vector2(12, -197), Vector2(9, -197)]
const SHIRT_STAIN := [Vector2(-14, -158), Vector2(2, -161), Vector2(9, -150), Vector2(4, -138),
		Vector2(-9, -136), Vector2(-17, -146)]

## Bangs `actor` up to `level` (1 or 2).
static func apply(actor: CutsceneActor, level: int) -> void:
	if actor == null or level <= 0:
		return
	_add(actor, BLACK_EYE_LEFT, BRUISE, BRUISE_Z)
	_add(actor, NOSE_BLOOD, BLOOD, BLOOD_Z)
	if level == 1:
		_add(actor, GASH, BLOOD, BLOOD_Z)
		return
	_add(actor, _mirrored(BLACK_EYE_LEFT), BRUISE, BRUISE_Z)
	_add(actor, GASH_DRIP, BLOOD, BLOOD_Z)
	_add(actor, SHIRT_STAIN, BLOOD, BLOOD_Z)

static func _add(actor: CutsceneActor, points: Array, color: Color, z: int) -> void:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array(points)
	shape.color = color
	shape.z_index = z
	actor.attach(shape)

static func _mirrored(points: Array) -> Array:
	var out := []
	for point: Vector2 in points:
		out.push_front(Vector2(-point.x, point.y))
	return out

## How beaten up the player is right now, from the ramp quests: 1 after the
## first spike-pit wipeout ("Downhill Billie") until the second run, 2 from
## the second ("Downhill Billie (Again)") until Grandpa gets his beer
## ("Beer Run"). 0 otherwise. PlayerCar bleeds a trail on the map by it.
static func current_level() -> int:
	if Quests.is_complete(&"ramp_again") and not Quests.is_complete(&"beer_run"):
		return 2
	if Quests.is_complete(&"ramp_check") and not Quests.is_complete(&"ramp_again"):
		return 1
	return 0
