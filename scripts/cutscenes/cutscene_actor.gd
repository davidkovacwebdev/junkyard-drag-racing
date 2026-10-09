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
## Squashed flat (see `flatten()`): this tall and this wide at full flatness.
const FLAT_HEIGHT := 0.07
const FLAT_WIDTH := 2.4
## Crying (see `cry()`): a tear from under each eye in turn, in character
## space, the same teardrops Grandpa sheds.
const TEAR_FROM := [Vector2(-12.0, -200.0), Vector2(12.0, -200.0)]
const TEAR_FALL := 46.0
const TEAR_Z := 11

var walking: bool = false
var talking: bool = false
## 0 standing, 1 pancaked flat on the ground (see `flatten()`).
var flatness: float = 0.0

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

## Squashes the character flat into the ground, cartoon style: a quick
## overshoot, then a pancake. Lying down (`fall_over()`) first is fine; the
## squash is along the ground either way.
func flatten(seconds: float = 0.12) -> Tween:
	walking = false
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "flatness", 1.0, seconds)
	return tween

## Teary-eyed for `seconds`: tears roll from each eye in turn. Fire and
## forget; pair it with a sob sound.
func cry(seconds: float = 2.0) -> void:
	var tears := maxi(1, int(seconds / 0.4))
	for i in tears:
		if not is_instance_valid(self):
			return
		_drop_tear(TEAR_FROM[i % TEAR_FROM.size()])
		await get_tree().create_timer(0.4).timeout

func _drop_tear(from: Vector2) -> void:
	var tear := Polygon2D.new()
	tear.polygon = PackedVector2Array([Vector2(0.0, -10.0), Vector2(6.0, 1.0),
			Vector2(4.0, 7.0), Vector2(-4.0, 7.0), Vector2(-6.0, 1.0)])
	tear.color = GrandpaNpc.TEAR_COLOR
	tear.position = from
	tear.z_index = TEAR_Z
	attach(tear)
	var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(tear, "position:y", from.y + TEAR_FALL, 0.5)
	fall.parallel().tween_property(tear, "modulate:a", 0.0, 0.2).set_delay(0.3)
	fall.tween_callback(tear.queue_free)

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
	var flat_x := lerpf(1.0, FLAT_WIDTH, flatness)
	var flat_y := lerpf(1.0, FLAT_HEIGHT, flatness)
	_body.scale = Vector2(_facing * _base_scale * (1.0 - squash) * flat_x, _base_scale * (1.0 + squash) * flat_y)
