class_name CarAccessory
extends Node2D
## A bolt-on extra riding on a car body (see AccessoryPartData). Purely
## decoration with no physics: the car's stats come from the data, and anything
## it does on its own (the axe chopping, the GPS arrow pointing) lives in a
## subclass. Authored with its origin at the mounting point: front accessories
## reach +x, rear ones -x, top ones -y.

@export var part_data: AccessoryPartData
@export_group("Race")
## Share of the car's weight this holds up all the time in a race (a balloon).
@export var race_lift_share: float = 0.0
## Share of the car's weight this presses it down with at full race speed
## (a spoiler), easing in with speed.
@export var race_downforce_share: float = 0.0
@export_group("")

## Speeds counted as "flat out" when easing animations in with speed: the map
## car is small and slow, a race rig is drawn at full size.
const MAP_TOP_SPEED := 420.0
const RACE_TOP_SPEED := 1500.0

## Off for previews (part icons, pickups, the junk heap) so they stay silent.
var audible: bool = false
## On in a drag race, where every car sound goes through RaceCarAudio.
var in_race: bool = false
## How fast the car is moving, measured from this node's own travel (px/s).
var moving_velocity: Vector2 = Vector2.ZERO

var _previous_position: Vector2
var _has_previous_position: bool = false

func _ready() -> void:
	# Hangs off the car rather than being part of its size, so the map car
	# isn't shrunk to fit a pair of horns.
	add_to_group(PartScale.OUTRIGGER_GROUP)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _has_previous_position:
		moving_velocity = moving_velocity.lerp((global_position - _previous_position) / delta, clampf(8.0 * delta, 0.0, 1.0))
	_previous_position = global_position
	_has_previous_position = true

func _physics_process(_delta: float) -> void:
	if race_lift_share == 0.0 and race_downforce_share == 0.0:
		return
	var body := race_body()
	if body == null:
		return
	var weight := body.mass * float(ProjectSettings.get_setting("physics/2d/default_gravity")) * body.gravity_scale
	var push := race_downforce_share * speed_fraction() - race_lift_share
	body.apply_central_force(body.global_transform.y.normalized() * weight * push)

## 0..1: how close to flat out the car is going.
func speed_fraction() -> float:
	return clampf(moving_velocity.length() / (RACE_TOP_SPEED if in_race else MAP_TOP_SPEED), 0.0, 1.0)

## The car's movement along its own length, -1..1 (+ = toward the front),
## whichever way the map car is facing.
func forward_fraction() -> float:
	var parent := get_parent() as Node2D
	if parent == null:
		return 0.0
	var local := parent.global_transform.affine_inverse().basis_xform(moving_velocity).normalized() * moving_velocity.length()
	return clampf(local.x / (RACE_TOP_SPEED if in_race else MAP_TOP_SPEED), -1.0, 1.0)

## Called once it's seated on its spot. Overridden by accessories that fit
## themselves to the body (the axe moves to the front of the roof, a skin
## repaints it).
func attach_to_body(_body: CarBody) -> void:
	pass

## Called for every wheel on the car once everything's mounted.
func paint_wheel(_wheel: Node2D) -> void:
	pass

func play_sound(sound_name: StringName, volume_db: float) -> void:
	if not audible:
		return
	if in_race:
		RaceCarAudio.play(self, sound_name, global_position, volume_db)
	else:
		Sfx.play(sound_name, volume_db)

## The body this rides on while it's a live race rig, or null.
func race_body() -> CarBody:
	var body := get_parent() as CarBody
	if in_race and body != null and not body.freeze:
		return body
	return null

## Instances every accessory `car` wears, through PartFactory.
static func instantiate_all(car: CarModelData) -> Array[CarAccessory]:
	var instances: Array[CarAccessory] = []
	for accessory_data in car.accessories:
		var instance := PartFactory.instantiate(accessory_data) as CarAccessory
		if instance != null:
			instances.append(instance)
	return instances

## Bolts every accessory onto `body` and lets each paint the wheels.
static func mount_all(body: CarBody, accessories: Array[CarAccessory], wheels: Array, sound_on: bool, race: bool) -> void:
	for accessory in accessories:
		accessory.audible = sound_on
		accessory.in_race = race
		body.add_child(accessory)
		body.place_accessory(accessory)
		for wheel in wheels:
			accessory.paint_wheel(wheel)
