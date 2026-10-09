class_name DriverSeat
extends Marker2D
## Where a driver sits on a body that has room for one (Grandpa's
## wheelchair): put this marker on the seat, at the driver's hips. CarView
## (the garage and the map car) and CarAssembler (races) call `seat()` to sit
## the player's character in it.
##
## The character rig is built standing, front on, so only its top half is
## used (torso, head, hair, eyes, accessory); the legs are two chunky bars
## bent at the knee, a thigh along the seat and a shin down to the footrest,
## with a boot on the end, in the colours of the character's own legs and
## boots.
##
## In a race the driver has no durability: a hard knock just sprays blood
## (`bleed()`). When the body breaks, `eject()` throws them clear as a
## ragdoll (DriverRagdoll), separate from the wreck.

## The character rig's size on the seat.
@export var character_scale: float = 0.55
## From the hips, in this marker's space: the knee, and the foot on the
## footrest.
@export var knee: Vector2 = Vector2(38.0, 0.0)
@export var foot: Vector2 = Vector2(78.0, 28.0)
@export var thigh_width: float = 10.0
@export var shin_width: float = 9.0

## The hips, in character space (feet at the origin).
const HIP_Y := -96.0
const LEG_FALLBACK := Color(0.28, 0.32, 0.45)
const BOOT_FALLBACK := Color(0.2, 0.18, 0.16)
const BOOT_SIZE := Vector2(16.0, 9.0)
## Below this Δv a knock doesn't draw blood.
const BLEED_VELOCITY := 220.0
const BLEED_COOLDOWN := 0.2

## The top half of the character (see CharacterAssembler), null until seated.
var upper: Node2D
## The bent legs and boot.
var legs: Node2D

var _bleed_cooldown := 0.0

## The seat on `body`, or null if it has none.
static func of(body: Node) -> DriverSeat:
	if body == null:
		return null
	for child in body.get_children():
		if child is DriverSeat:
			return child
	return null

func _process(delta: float) -> void:
	_bleed_cooldown -= delta

func seat(character: CharacterData) -> void:
	if character == null:
		return
	if is_instance_valid(upper):
		upper.free()
	if is_instance_valid(legs):
		legs.free()
	legs = Node2D.new()
	legs.name = "Legs"
	add_child(legs)
	var leg_color := _first_color(character.legs_scene, LEG_FALLBACK)
	var boot_color := _first_color(character.boots_scene, BOOT_FALLBACK)
	_add_polygon(legs, FlatProps.sliver(Vector2.ZERO, knee, thigh_width), leg_color)
	_add_polygon(legs, FlatProps.sliver(knee, foot, shin_width), leg_color)
	_add_polygon(legs, PackedVector2Array([
		foot + Vector2(-BOOT_SIZE.x * 0.35, -BOOT_SIZE.y * 0.5), foot + Vector2(BOOT_SIZE.x * 0.65, -BOOT_SIZE.y * 0.5),
		foot + Vector2(BOOT_SIZE.x * 0.65, BOOT_SIZE.y * 0.5), foot + Vector2(-BOOT_SIZE.x * 0.35, BOOT_SIZE.y * 0.5),
	]), boot_color)
	var top_half := character.duplicate() as CharacterData
	top_half.legs_scene = null
	top_half.boots_scene = null
	upper = CharacterAssembler.assemble(top_half, self, Vector2(0.0, -HIP_Y * character_scale))
	upper.scale = Vector2.ONE * character_scale
	# Child order instead of z_index, so the wheels and the rest of the car
	# still draw over the driver where they should.
	CharacterAssembler.layer_by_child_order(upper)

func is_seated() -> bool:
	return is_instance_valid(upper)

## A knock to the car with the driver in it: blood flies off them (and a
## wet thud) when it's hard enough. No damage, the driver can't break.
func bleed(delta_v: float, spray_parent: Node) -> void:
	if not is_seated() or delta_v < BLEED_VELOCITY or _bleed_cooldown > 0.0:
		return
	_bleed_cooldown = BLEED_COOLDOWN
	var at := upper.to_global(Vector2(0.0, -150.0))
	BloodSpray.spray(spray_parent, at, delta_v)
	RaceCarAudio.play(spray_parent, &"flesh_splat", at, linear_to_db(clampf(delta_v / 900.0, 0.3, 1.0)))

## The body broke: the driver flies clear as a ragdoll, carrying the car's
## speed, colliding like the car's parts did.
func eject(parent: Node, velocity: Vector2, layer: int, mask: int) -> DriverRagdoll:
	if not is_seated():
		return null
	var ragdoll := DriverRagdoll.from_seat(self, parent, velocity, layer, mask)
	upper = null
	legs = null
	return ragdoll

static func _first_color(scene: PackedScene, fallback: Color) -> Color:
	if scene == null:
		return fallback
	var instance := scene.instantiate()
	var color := fallback
	for child in instance.get_children():
		if child is Polygon2D:
			color = (child as Polygon2D).color
			break
	instance.free()
	return color

static func _add_polygon(parent: Node, points: PackedVector2Array, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
