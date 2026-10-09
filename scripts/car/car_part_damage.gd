class_name CarPartDamage
extends Node
## Tracks impact damage for one physics part (a car body or wheel) and
## fires `broken` once its durability runs out.
##
## Damage per hit is proportional to the momentum the part just absorbed
## (mass * |Δv| in a single physics step) — a plain, physically honest
## stand-in for impact force that needs no collision-shape math: heavier
## parts deal and take harder hits, faster impacts deal and take harder
## hits, both for free from the one formula. Small jostles from normal
## driving stay under the threshold; slamming into the end wall does not.

signal broken
## Every knock over the impact threshold, before it's turned into damage
## (`delta_v` is the part's change in speed in that step).
signal impacted(delta_v: float)

const GROUP := &"car_part_damage"

@export var target: RigidBody2D
@export var part_data: PartData

const IMPACT_VELOCITY_THRESHOLD := 200.0
const DAMAGE_PER_MOMENTUM := 0.006
## A hit this hard (Δv) or harder knocks at full volume.
const LOUDEST_IMPACT_VELOCITY := 900.0
const IMPACT_SOUND_COOLDOWN := 0.15

## 0..1 share of impact damage soaked up before it counts. Only bumps and
## landings: apply_damage() from anything else is taken in full.
var absorption: float = 0.0
## 0..1 extra share soaked up only when the hit came from the ground, not
## from another car. Needs contact_monitor on the target to tell them apart.
var ground_absorption: float = 0.0
## Scales the part's own durability (a turtle shell toughens every part).
var durability_multiplier: float = 1.0
## Replaces the part's own knock when set.
var impact_sound: StringName = &""
## Other parts whose contacts also count when telling a ground hit from a car
## hit (the body lands through its wheels, so it checks them too).
var linked_contact_parts: Array = []
var max_durability: float = 100.0
var current_durability: float = 100.0
var is_broken: bool = false

var _prev_velocity := Vector2.ZERO
var _impact_sound_cooldown := 0.0

func _ready() -> void:
	add_to_group(GROUP)
	if part_data != null:
		max_durability = part_data.durability * durability_multiplier
	current_durability = max_durability

## The tracker on `part`, or null if it has none.
static func of(part: Node) -> CarPartDamage:
	for child in part.get_children():
		if child is CarPartDamage:
			return child
	return null

## For a caller that pauses this tracker (set_physics_process(false)) for a
## stretch and later re-arms it: without this, the first step back would
## compare the part's current velocity against whatever _prev_velocity was
## when it got paused, reading as one huge Δv spike and breaking the part
## on a hit that never actually happened.
func resync() -> void:
	if is_instance_valid(target):
		_prev_velocity = target.linear_velocity

func _physics_process(delta: float) -> void:
	_impact_sound_cooldown -= delta
	# is_instance_valid, not a plain null check: target is a dangling
	# reference (not nulled out) once queue_free()'d, which a `== null`
	# check doesn't catch — surfaced by chaotic multi-car pileups where
	# a wheel/body can get freed out from under its own damage tracker.
	if is_broken or not is_instance_valid(target):
		return
	var velocity := target.linear_velocity
	var delta_v := (velocity - _prev_velocity).length()
	_prev_velocity = velocity
	if delta_v < IMPACT_VELOCITY_THRESHOLD:
		return
	impacted.emit(delta_v)
	var momentum := target.mass * delta_v
	var total_absorption := absorption
	if ground_absorption > 0.0 and _is_ground_hit():
		total_absorption = 1.0 - (1.0 - absorption) * (1.0 - ground_absorption)
	apply_damage(momentum * DAMAGE_PER_MOMENTUM * (1.0 - total_absorption))
	if not is_broken and _impact_sound_cooldown <= 0.0:
		_impact_sound_cooldown = IMPACT_SOUND_COOLDOWN
		var loudness := clampf(delta_v / LOUDEST_IMPACT_VELOCITY, 0.25, 1.0)
		var knock := impact_sound
		if knock == &"":
			knock = part_data.impact_sound if part_data != null else &"bump"
		RaceCarAudio.play(self, knock, target.global_position, linear_to_db(loudness))

func _is_ground_hit() -> bool:
	for part in [target] + linked_contact_parts:
		if not is_instance_valid(part):
			continue
		for body in part.get_colliding_bodies():
			if body is RigidBody2D:
				return false
	return true

func apply_damage(amount: float) -> void:
	if is_broken or not is_instance_valid(target):
		return
	current_durability -= amount
	if current_durability <= 0.0:
		is_broken = true
		RaceCarAudio.play(self, &"collision", target.global_position, -2.0)
		broken.emit()
