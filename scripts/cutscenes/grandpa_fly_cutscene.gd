class_name GrandpaFlyCutscene
extends Cutscene
## After "Visiting Hours (Again)": the player finds Grandpa leaning back in
## his chair, staring up at the sky. "Ever wondered... what it would be
## like... if humans could fly?" The player tells him they can: airplanes and
## stuff. He has an idea, and is helped into the car, wheelchair and all.
## Unlocked by "Visiting Hours (Again)"; plays when the player talks to him
## while it's available (GrandpaNpc), and gives "Up, Up and Away" (HeliStory
## takes it from there).
##
## The words live in res://cutscenes/grandpa_fly.tres; edit them in the
## inspector.

const ID := &"grandpa_fly"
const GRANDPA := preload("res://characters/grandpa.tres")
## How far he leans back to look up, like a sip but held.
const SKY_LEAN := 0.16

@export var speaker_name: String = "Grandpa"
@export var wondered_line: String = "Ever wondered?..."
@export var like_line: String = "What it would be like..."
@export var fly_line: String = "If humans could fly?..."
@export var we_can_line: String = "Yes, and we can fly. I flew once. We have airplanes and stuff."
@export var damned_line: String = "Well I'll be damned, you're right..."
@export var idea_line: String = "I have an idea."
@export var car_line: String = "Help me into your car. Chair goes in the back."

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
@export var camera_lift: float = 70.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	default_quest = preload("res://quests/heli_parts.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var player_spot := grandpa.global_position + player_offset
	await Cutscenes.fade_out(0.0)
	grandpa.park_car_for_scene()
	# Leaning back, eyes on the sky.
	var lean := SKY_LEAN * (1.0 if grandpa.facing_right else -1.0)
	grandpa.actor.rotation = -lean
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, player_spot, false)
		CharacterInjuries.apply(player, CharacterInjuries.current_level())
	Cutscenes.cut_to((player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift), zoom)
	await Cutscenes.fade_in(0.8)
	Cutscenes.sound(&"cricket_chirp", -10.0)
	await Cutscenes.wait(0.8)

	await _grandpa_says(wondered_line)
	await Cutscenes.wait(0.3)
	await _grandpa_says(like_line)
	await Cutscenes.wait(0.3)
	await _grandpa_says(fly_line)
	await Cutscenes.subtitle(my_name, me, we_can_line, player)
	# Sits bolt upright.
	grandpa.actor.rotation = 0.0
	if not Cutscenes.is_skipping():
		grandpa.widen_eyes()
	await _grandpa_says(damned_line)
	await Cutscenes.wait(0.3)
	if not Cutscenes.is_skipping():
		grandpa.laugh(1.0, -6.0, &"grandpa_cackle")
	await _grandpa_says(idea_line)
	await _grandpa_says(car_line)

	# Out of the chair and into the car, the chair in after him.
	if player != null:
		await Cutscenes.walk(player, grandpa.global_position + Vector2(50.0, 0.0), 120.0)
	if not Cutscenes.is_skipping():
		await Cutscenes.play_tween(grandpa.roll_to(Vector2(90.0, 20.0), 0.8))
	await Cutscenes.fade_out(0.5)
	Cutscenes.sound(&"grandpa_heave", -6.0)
	await Cutscenes.wait(0.8)
	Cutscenes.sound(&"door_close", -4.0)
	await Cutscenes.wait(0.4)
	Cutscenes.sound(&"trunk_close", -6.0)
	grandpa.roll_to(Vector2.ZERO, 0.01)
	# Gone from his chair before the lights come up (HeliStory keeps him so).
	grandpa.visible = false
	await Cutscenes.wait(0.3)

func _grandpa_says(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
