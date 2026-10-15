class_name CarPartDamage
extends Node
## Tracks impact damage for one physics part (a car body or wheel) and
## fires `broken` once its durability runs out.
##
## Damage per hit is proportional to the momentum the part just absorbed
## beyond the threshold (mass * (|Δv| - threshold) in a single physics step) —
## a plain stand-in for impact force that needs no collision-shape math:
## heavier parts and faster impacts both hit harder, for free from the one
## formula. Counting only the excess keeps knocks just over the line (a
## suspension bottoming out at the foot of the ramp) as chip damage, while
## slamming into the end wall still wrecks.

signal broken
## Every knock over the impact threshold, before it's turned into damage
## (`delta_v` is the part's change in speed in that step).
signal impacted(delta_v: float)

const GROUP := &"car_part_damage"

@export var target: RigidBody2D
@export var part_data: PartData

const IMPACT_VELOCITY_THRESHOLD := 200.0
const DAMAGE_PER_MOMENTUM := 0.006
## Scales every part's durability in play, leaving its rated stat untouched.
const GLOBAL_DURABILITY_MULTIPLIER := 1.25
## Landings and ground knocks hurt this much of a car-on-car hit of the same force.
const GROUND_HIT_DAMAGE_SCALE := 0.6
## A hit this hard (Δv) or harder knocks at the top of KNOCK_VOLUME_DB, one
## just over the threshold at the bottom. A knock is a small detail in the mix
## (see the sound-design skill's levels): kept well under a part breaking
## (-2 dB) so stacked knocks never push the master limiter into pumping.
const LOUDEST_IMPACT_VELOCITY := 900.0
const KNOCK_VOLUME_DB := Vector2(-22.0, -8.0)

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
## Which knocks get heard. CarAssembler gives every part of a car the same one,
## so the car knocks as one thing rather than once per part.
var knock_gate := CarKnockGate.new()
## Other parts whose contacts also count when telling a ground hit from a car
## hit (the body lands through its wheels, so it checks them too).
var linked_contact_parts: Array = []
var max_durability: float = 100.0
var current_durability: float = 100.0
var is_broken: bool = false

var _prev_velocity := Vector2.ZERO

func _ready() -> void:
	add_to_group(GROUP)
	if part_data != null:
		max_durability = part_data.durability * durability_multiplier * GLOBAL_DURABILITY_MULTIPLIER
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

func _physics_process(_delta: float) -> void:
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
	var momentum := target.mass * (delta_v - IMPACT_VELOCITY_THRESHOLD)
	var total_absorption := absorption
	var damage_scale := 1.0
	if _is_ground_hit():
		total_absorption = 1.0 - (1.0 - absorption) * (1.0 - ground_absorption)
		damage_scale = GROUND_HIT_DAMAGE_SCALE
	apply_damage(momentum * DAMAGE_PER_MOMENTUM * damage_scale * (1.0 - total_absorption))
	var strength := clampf(inverse_lerp(IMPACT_VELOCITY_THRESHOLD, LOUDEST_IMPACT_VELOCITY, delta_v), 0.0, 1.0)
	var knock_db := lerpf(KNOCK_VOLUME_DB.x, KNOCK_VOLUME_DB.y, strength)
	if not is_broken and knock_gate.allow(db_to_linear(knock_db)):
		var knock := impact_sound
		if knock == &"":
			knock = part_data.impact_sound if part_data != null else &"bump"
		RaceCarAudio.play(self, knock, target.global_position, knock_db)

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
