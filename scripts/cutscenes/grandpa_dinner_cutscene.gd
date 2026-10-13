class_name GrandpaDinnerCutscene
extends Cutscene
## After "Gone Fishin'": Grandpa needs to fish. Not with the crane: he's
## spent all his money on beer and needs his dinner. Fishing rods? He mocks
## the question, then just tells the player to follow him. Unlocked by
## "Gone Fishin'"; plays when the player talks to him while it's available
## (GrandpaNpc), and gives "Fish Supper" (DinnerStory takes it from there).
##
## The words live in res://cutscenes/grandpa_dinner.tres; edit them in the
## inspector.

const ID := &"grandpa_dinner"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
@export var need_line: String = "Son, I need to fish."
@export var already_line: String = "But we already went fishing."
@export var dinner_line: String = "No, not the crane. I need me some dinner. Spent all my money on beer."
@export var rods_line: String = "Oh, do you have fishing rods?"
@export var mock_line: String = "ndoo yoo haabe fishiing rooods"
@export var silence_line: String = "..."
@export var follow_line: String = "Just follow me."

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
@export var camera_lift: float = 70.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	default_quest = preload("res://quests/fish_supper.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var player_spot := grandpa.global_position + player_offset
	await Cutscenes.fade_out(0.0)
	grandpa.park_car_for_scene()
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, player_spot, false)
	Cutscenes.cut_to((player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift), zoom)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.wait(0.4)

	await _grandpa_says(need_line)
	await Cutscenes.subtitle(my_name, me, already_line, player)
	if not Cutscenes.is_skipping():
		grandpa.twitch(0.8)
	await _grandpa_says(dinner_line)
	await Cutscenes.subtitle(my_name, me, rods_line, player)
	# Mocking: the voice goes all goofy.
	if not Cutscenes.is_skipping():
		grandpa.widen_eyes(1.2, -8.0)
	await _grandpa_says(mock_line)
	await Cutscenes.subtitle(my_name, me, silence_line, player)
	await Cutscenes.wait(0.6)
	await _grandpa_says(follow_line)
	await Cutscenes.wait(0.3)

func _grandpa_says(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
