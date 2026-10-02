class_name GrandpaRaceCutscene
extends Cutscene
## Grandpa's first-race quest: tears in his eyes, he tells the player they're
## ready for their first drag race, hands over the $40 entry fee (the quest's
## `start_money`) and bursts into loud crying. Unlocked by "Gone Fishin'";
## plays when the player talks to him while it's available (GrandpaNpc), and
## gives "Make Me Proud".
##
## The words live in res://cutscenes/grandpa_race.tres; edit them in the
## inspector. The beats:
##   - a tear rolls down each cheek as the scene fades in
##   - he says the `ready_lines`, the player asks the `player_line`
##   - he says the `proud_lines`, then bawls out loud (camera rattles along)

const ID := &"grandpa_race"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
## Said quietly, teary-eyed. These defaults are the scene as written; edits
## in the inspector on the .tres override them.
@export_multiline var ready_lines: PackedStringArray = [
	"*sniff* {player}... I think you're ready.",
]
## What the player asks.
@export var player_line: String = "For what?"
@export_multiline var proud_lines: PackedStringArray = [
	"For your first drag race.",
	"Use the parts we gathered so far. Here's the money for the race. Make me proud!",
]

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
@export var bawl_seconds: float = 2.6

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/first_race.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot, false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)

	if not Cutscenes.is_skipping():
		grandpa.tear_up(2)
	await Cutscenes.wait(1.0)
	for line in ready_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character, player_line, player)
	if player != null:
		Cutscenes.hop(player, 18.0)
	for line in proud_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
		if not Cutscenes.is_skipping():
			grandpa.tear_up(1)

	# And then he loses it.
	if not Cutscenes.is_skipping():
		grandpa.sob(bawl_seconds, -1.0)
		Cutscenes.shake(5.0, bawl_seconds)
	await Cutscenes.wait(bawl_seconds + 0.3)
