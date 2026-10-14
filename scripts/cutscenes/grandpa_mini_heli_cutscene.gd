class_name GrandpaMiniHeliCutscene
extends Cutscene
## After "Chains": Grandpa's built a one-man helicopter out of the engine and
## tail rotor from "Up, Up and Away", and he's whacking it with his wrench.
## "Wow, you built this?" "Yeeep, and you'll have to try it out." Is it safe?
## Super safe. Sure? He just stares. It's the same as riding a bicycle.
## Unlocked by "Chains"; plays when the player talks to him while it's
## available (GrandpaNpc), and gives "Test Pilot" (HeliTestStory then lets
## the player climb in with E).
##
## The words live in res://cutscenes/grandpa_mini_heli.tres; edit them in
## the inspector.

const ID := &"grandpa_mini_heli"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
@export var built_line: String = "Wow, you built this?"
@export var yeep_line: String = "Yeeep, and you'll have to try it out."
@export var safe_line: String = "But is it safe?"
@export var super_safe_line: String = "Oh yeah, super safe.."
@export var sure_line: String = "U sure?"
@export var what_line: String = "Okay, what do I have to do?"
@export var bicycle_line: String = "It's the same as riding a bicycle."

@export_group("Staging")
## From Grandpa, who's sitting by its nose (HeliTestStory).
@export var player_offset := Vector2(90.0, 150.0)
@export var car_offset := Vector2(330.0, 160.0)
@export var zoom: float = 1.25
@export var camera_lift: float = 60.0
## How long he just stares.
@export var stare_seconds: float = 2.6

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	default_quest = preload("res://quests/heli_test.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var story := Cutscenes.get_tree().get_first_node_in_group(HeliTestStory.GROUP) as HeliTestStory
	var pad := story.pad() if story != null else null
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	await Cutscenes.fade_out(0.0)
	if story != null:
		story.bring_grandpa_to_heli()
	var player_spot := grandpa.global_position + player_offset
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	if car != null:
		car.park(grandpa.global_position + car_offset, false)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, player_spot, false)
		CharacterInjuries.apply(player, CharacterInjuries.current_level())
	var middle := grandpa.global_position if pad == null else (grandpa.global_position + pad.global_position) * 0.5
	Cutscenes.cut_to((player_spot + middle) * 0.5 + Vector2(0.0, -camera_lift), zoom)
	await Cutscenes.fade_in(0.8)

	# Still at it when the player walks up.
	for i in 2:
		await _whack(pad)
	await Cutscenes.subtitle(my_name, me, built_line, player)
	grandpa.actor.face(true)
	await _grandpa_says(yeep_line)
	await Cutscenes.subtitle(my_name, me, safe_line, player)
	await _grandpa_says(super_safe_line)
	await Cutscenes.subtitle(my_name, me, sure_line, player)

	# He just stares.
	await Cutscenes.wait(stare_seconds * 0.4)
	Cutscenes.sound(&"cricket_chirp", -8.0)
	await Cutscenes.wait(stare_seconds * 0.6)

	await Cutscenes.subtitle(my_name, me, what_line, player)
	await _grandpa_says(bicycle_line)
	await Cutscenes.wait(0.3)
	if pad != null:
		grandpa.face_wrench_toward(pad.global_position)

## One swing of the wrench at the helicopter, and a tinny bonk off the tub.
func _whack(pad: MiniHeliPad) -> void:
	if not Cutscenes.is_skipping():
		grandpa.bang(-6.0, true)
	await Cutscenes.wait(0.22)
	if pad != null:
		Cutscenes.sound(&"car_whack", -10.0, pad.global_position)
	await Cutscenes.wait(0.55)

func _grandpa_says(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
