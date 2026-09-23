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

@export var target: RigidBody2D
@export var part_data: PartData

const IMPACT_VELOCITY_THRESHOLD := 200.0
const DAMAGE_PER_MOMENTUM := 0.006

var current_durability: float = 100.0
var is_broken: bool = false

var _prev_velocity := Vector2.ZERO

func _ready() -> void:
	if part_data != null:
		current_durability = part_data.durability

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
	var momentum := target.mass * delta_v
	current_durability -= momentum * DAMAGE_PER_MOMENTUM
	if current_durability <= 0.0:
		is_broken = true
		broken.emit()
