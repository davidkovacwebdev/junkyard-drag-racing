class_name HeliCrashSiteCutscene
extends Cutscene
## "Up, Up and Away", at the crashed helicopter: Grandpa climbs out of the
## car into his chair, wheels himself over to the wreck and whacks it with his
## wrench. Mumbles. Whacks it again. Mumbles. Then: "Hit it 10 times with your
## car." He climbs back in to enjoy the ride. Played by HeliStory when the
## car reaches the crash site, which then counts the rams.
##
## The words live in res://cutscenes/heli_crash_site.tres; edit them in the
## inspector.

const ID := &"heli_crash_site"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
@export var mumble_line: String = "Hmmm... mm. Hrrmm-hm..."
@export var mumble_again_line: String = "Mm-hm... yep... nnope. Tough old bird..."
@export var hit_it_line: String = "Hit it 10 times with your car."
@export var normal_line: String = "I guess that's what we normally do around here."

@export_group("Staging")
@export var zoom: float = 1.4
## Where he parks by the wreck, from the helicopter's origin, on the car's
## side of it (x is flipped when the car's on the left).
@export var wreck_spot := Vector2(250.0, 60.0)
@export var roll_speed: float = 260.0

## Set by HeliStory before playing: Grandpa (hidden in the car till now) and
## the wreck.
var grandpa: GrandpaNpc
var helicopter: CrashedHelicopter

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa) or not is_instance_valid(helicopter):
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var car_at := car.global_position if car != null else helicopter.global_position + Vector2(500.0, 80.0)
	var side := 1.0 if car_at.x >= helicopter.global_position.x else -1.0
	var heli_at := helicopter.global_position
	var spot := heli_at + Vector2(wreck_spot.x * side, wreck_spot.y)
	var home := grandpa.global_position

	# Out of the car: the player, then the chair, then Grandpa into it.
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, car_at + Vector2(-70.0 * side, 16.0), side < 0.0)
		Cutscenes.sound(&"door_close", -6.0)
	await Cutscenes.camera_to((car_at + heli_at) * 0.5 + Vector2(0.0, -90.0), zoom, 0.9)
	Cutscenes.sound(&"trunk_open", -6.0)
	await Cutscenes.wait(0.4)
	Cutscenes.sound(&"grandpa_heave", -6.0)
	grandpa.global_position = car_at + Vector2(90.0 * side, 40.0)
	grandpa.actor.face(side < 0.0)
	grandpa.visible = true
	await Cutscenes.wait(0.5)

	# Over to the wreck.
	await _roll(spot)
	grandpa.face_wrench_toward(heli_at)
	if player != null:
		await Cutscenes.walk(player, spot + Vector2(150.0 * side, 10.0), 150.0)
		Cutscenes.face(player, side < 0.0)

	await _whack()
	await _grandpa_says(mumble_line)
	await Cutscenes.wait(0.3)
	await _whack()
	await _grandpa_says(mumble_again_line)
	await Cutscenes.wait(0.4)
	grandpa.actor.face(side > 0.0)
	await _grandpa_says(hit_it_line)
	await Cutscenes.subtitle(my_name, me, normal_line, player)

	# Back in the car, to enjoy the ride.
	await _roll(car_at + Vector2(90.0 * side, 40.0))
	await Cutscenes.fade_out(0.5)
	Cutscenes.sound(&"grandpa_heave", -6.0)
	await Cutscenes.wait(0.6)
	Cutscenes.sound(&"door_close", -4.0)
	grandpa.visible = false
	grandpa.global_position = home
	grandpa.actor.face(grandpa.facing_right)
	await Cutscenes.wait(0.3)

## Wheels him to `to`, squeaking, facing the way he's going.
func _roll(to: Vector2) -> void:
	var from := grandpa.global_position
	if absf(to.x - from.x) > 1.0:
		grandpa.actor.face(to.x > from.x)
	Cutscenes.sound(&"wheelchair_squeak", -6.0, from)
	var seconds := maxf(from.distance_to(to) / roll_speed, 0.3)
	var tween := grandpa.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(grandpa, "global_position", to, seconds)
	await Cutscenes.play_tween(tween)
	grandpa.global_position = to

## One swing of the wrench at the wreck: his clunk, a hollow bonk off the
## hull, and the whole thing shudders.
func _whack() -> void:
	if not Cutscenes.is_skipping():
		grandpa.bang(-4.0, true)
	await Cutscenes.wait(0.22)
	Cutscenes.sound(&"car_whack", -6.0, helicopter.global_position)
	helicopter.shudder()
	await Cutscenes.wait(0.6)

func _grandpa_says(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
