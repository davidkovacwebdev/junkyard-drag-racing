class_name CutsceneActor
extends Node2D
## A character standing in the world for a cutscene: the same CharacterRig
## NPCs use, plus the few chunky moves a cutscene needs — walk (a bouncy
## waddle), hop, fall flat, and a talking squash while their subtitle types.
##
## The root moves around the world; `_body` does the bobbing and tipping, so
## the two never fight. Made and cleaned up by Cutscenes.spawn_actor().

const WALK_BOB_PIXELS := 14.0
const WALK_STEPS_PER_SECOND := 4.0
const TALK_SQUASH := 0.05

var walking: bool = false
var talking: bool = false

var _body: Node2D
var _base_scale: float = 1.0
var _facing: float = 1.0
var _time: float = 0.0

func setup(character: CharacterData, scale_factor: float) -> void:
	_base_scale = scale_factor
	_body = Node2D.new()
	add_child(_body)
	var rig := CharacterRig.new()
	rig.character_data = character
	_body.add_child(rig)

## Puts `prop` on the character (a held tool, say). Its position is in
## character space, so it bobs, flips and tips along with the body.
func attach(prop: Node2D) -> void:
	_body.add_child(prop)

func face(right: bool) -> void:
	_facing = 1.0 if right else -1.0

## Tween the walk; the waddle runs while it's moving.
func walk_to(to: Vector2, speed: float) -> Tween:
	face(to.x >= global_position.x)
	walking = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", to, global_position.distance_to(to) / maxf(speed, 1.0))
	tween.finished.connect(func() -> void:
		walking = false
		_body.position.y = 0.0)
	return tween

func hop(height: float) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_body, "position:y", -height, 0.16).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN)
	return tween

## Tips over backwards and lands with a little bounce.
func fall_over() -> Tween:
	walking = false
	var direction := -_facing
	var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "rotation", direction * PI * 0.5, 0.45)
	return tween

func stand_up() -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "rotation", 0.0, 0.35)
	return tween

func _process(delta: float) -> void:
	_time += delta
	if walking:
		_body.position.y = -absf(sin(_time * PI * WALK_STEPS_PER_SECOND)) * WALK_BOB_PIXELS
		_body.skew = sin(_time * PI * WALK_STEPS_PER_SECOND) * 0.08
	else:
		_body.skew = 0.0
	var squash := sin(_time * TAU * 7.0) * TALK_SQUASH if talking else 0.0
	_body.scale = Vector2(_facing * _base_scale * (1.0 - squash), _base_scale * (1.0 + squash))
