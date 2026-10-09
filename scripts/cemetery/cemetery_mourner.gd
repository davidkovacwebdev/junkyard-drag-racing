class_name CemeteryMourner
extends StaticBody2D
## Someone standing at a grave with their head bowed, rocking ever so
## slightly. Not someone you can talk to; cutscenes use `actor` for the
## talking squash and `face()` to turn them around.

const ACTOR_SCALE := 0.55
## The slow sway of someone trying to hold it together.
const SWAY_ANGLE := 0.03
const SWAY_SPEED := 1.1

var character_data: CharacterData
var actor: CutsceneActor
var facing_right: bool = true
## Something they hold (the Drag Queen's family's trans flags), in character
## space. Optional.
var held_prop: PackedScene

var _time: float = 0.0

func _ready() -> void:
	actor = CutsceneActor.new()
	actor.setup(character_data, ACTOR_SCALE)
	add_child(actor)
	actor.face(facing_right)
	if held_prop != null:
		actor.attach(held_prop.instantiate())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44.0, 14.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -7.0)
	add_child(collision)
	_time = randf() * TAU

func _process(delta: float) -> void:
	_time += delta * SWAY_SPEED
	actor.rotation = sin(_time) * SWAY_ANGLE

func face(right: bool) -> void:
	actor.face(right)
