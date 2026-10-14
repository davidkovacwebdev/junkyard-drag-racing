class_name GrandpaMiniHeliReportCutscene
extends Cutscene
## Handing in "Test Pilot": the player's back from the crash, and Grandpa's
## delighted. "Well, I call it a success!" "I BARELY SURVIVED!" He sighs:
## "Ok, I'm calling it quits." The quest's `turn_in_cutscene`; GrandpaNpc
## finishes the quest (which hands out "King of the Hill") once it's over.
##
## The words live in res://cutscenes/grandpa_mini_heli_report.tres; edit
## them in the inspector.

const ID := &"grandpa_mini_heli_report"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
@export var success_line: String = "Well, I call it a success!"
@export var survived_line: String = "I BARELY SURVIVED!"
@export var quits_line: String = "Ok, I'm calling it quits."

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
@export var camera_lift: float = 70.0

## Set by GrandpaNpc before playing.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID

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
	await Cutscenes.wait(0.3)

	if not Cutscenes.is_skipping():
		grandpa.laugh(1.0, -6.0)
	await _grandpa_says(success_line)
	if player != null:
		Cutscenes.hop(player, 30.0)
	Cutscenes.shake(8.0, 0.3)
	await Cutscenes.subtitle(my_name, me, survived_line, player)
	await Cutscenes.wait(0.4)
	if not Cutscenes.is_skipping():
		grandpa.sigh()
	await _grandpa_says(quits_line)
	await Cutscenes.wait(0.4)

func _grandpa_says(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
