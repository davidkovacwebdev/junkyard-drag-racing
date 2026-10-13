class_name GrandpaExCutscene
extends Cutscene
## After "Beer Run": Grandpa's ex is in the hospital, and he's
## sorry... that he hasn't the legs to go and make fun of her. So the player
## helps him out of his wheelchair and into their car. Unlocked by "Beer
## Run"; plays when the player talks to him while it's available
## (GrandpaNpc), and gives "Visiting Hours" (ExStory takes it from there).
##
## The words live in res://cutscenes/grandpa_ex.tres; edit them in the
## inspector.

const ID := &"grandpa_ex"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
@export var ex_line: String = "My ex is in the hospital."
@export var sorry_line: String = "Oh, I'm sorry, gramps."
@export var sorry_too_line: String = "I'm sorry too..."
@export var legs_line: String = "...because I lack the legs to go and make fun of her."
@export var cmon_line: String = "Oh, c'mon..."
@export var car_line: String = "I know. Help me get into your car."

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
@export var camera_lift: float = 70.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	default_quest = preload("res://quests/ex_visit.tres")

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
		CharacterInjuries.apply(player, CharacterInjuries.current_level())
	Cutscenes.cut_to((player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift), zoom)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.wait(0.4)

	await _grandpa_says(ex_line)
	await Cutscenes.subtitle(my_name, me, sorry_line, player)
	if not Cutscenes.is_skipping():
		grandpa.sigh()
	await _grandpa_says(sorry_too_line)
	await Cutscenes.wait(0.4)
	if not Cutscenes.is_skipping():
		grandpa.laugh(1.2, -6.0, &"grandpa_cackle")
	await _grandpa_says(legs_line)
	await Cutscenes.subtitle(my_name, me, cmon_line, player)
	await _grandpa_says(car_line)

	# Out of the chair and into the car.
	if player != null:
		await Cutscenes.walk(player, grandpa.global_position + Vector2(50.0, 0.0), 120.0)
	if not Cutscenes.is_skipping():
		await Cutscenes.play_tween(grandpa.roll_to(Vector2(90.0, 20.0), 0.8))
	await Cutscenes.fade_out(0.5)
	Cutscenes.sound(&"grandpa_heave", -6.0)
	await Cutscenes.wait(0.8)
	Cutscenes.sound(&"door_close", -4.0)
	await Cutscenes.wait(0.4)
	Cutscenes.sound(&"door_close", -6.0)
	grandpa.roll_to(Vector2.ZERO, 0.01)
	await Cutscenes.wait(0.3)

func _grandpa_says(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
