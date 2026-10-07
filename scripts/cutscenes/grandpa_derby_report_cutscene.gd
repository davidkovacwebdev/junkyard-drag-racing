class_name GrandpaDerbyReportCutscene
extends Cutscene
## Handing in "Wrap It Up": the player comes back from the Demolition Derby.
## Won, and Grandpa says the `won_line` and drinks to it. Lost, and he says
## the `lost_line` like he saw it coming, and cracks open a fresh beer. The
## quest's `turn_in_cutscene`; GrandpaNpc finishes the quest once it's over.
##
## The words live in res://cutscenes/grandpa_derby_report.tres; edit them in
## the inspector.

const ID := &"grandpa_derby_report"
const QUEST_ID := &"derby_debut"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var won_line: String = "Atta boy."
@export var lost_line: String = "Ah. Expected."

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var won := String(Quests.notes.get(QUEST_ID, "")) == "won"
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)
	await Cutscenes.wait(0.4)

	if won:
		await _grandpa(won_line)
		if not Cutscenes.is_skipping():
			grandpa.sip(-8.0)
		await Cutscenes.wait(1.0)
		return

	await _grandpa(lost_line)
	await Cutscenes.wait(0.3)
	# A fresh one: the crack, then a long pull.
	Cutscenes.sound(&"beer_crack", -4.0)
	await Cutscenes.wait(0.5)
	if not Cutscenes.is_skipping():
		grandpa.sip(-6.0)
	await Cutscenes.wait(1.2)

func _grandpa(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
