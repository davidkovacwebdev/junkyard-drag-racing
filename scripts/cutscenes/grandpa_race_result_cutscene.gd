class_name GrandpaRaceResultCutscene
extends Cutscene
## After "Make Me Proud": Grandpa asks how the first race went, and the
## scene plays out the way it actually did (the race quest's note, "won" or
## "lost"). Either way he sends the player off to grind money and scrap, and
## gives "Talk Shop". Unlocked by "Make Me Proud"; plays when the player
## talks to him while it's available (GrandpaNpc).
##
## The words live in res://cutscenes/grandpa_race_result.tres; edit them in
## the inspector. The beats:
##   - he asks the `ask_line`
##   - lost: the player says `player_lost_line`, he takes a long sip of beer,
##     then the `lost_lines`
##   - won: the player says `player_won_line` and jumps, he hiccups, then the
##     `won_lines`

const ID := &"grandpa_race_result"
const GRANDPA := preload("res://characters/grandpa.tres")
## Whose note says how the race went.
const RACE_QUEST := &"first_race"

@export var speaker_name: String = "Grandpa"
@export var ask_line: String = "So? How'd it go?"
@export var player_lost_line: String = "I lost."
@export var player_won_line: String = "I won!"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var lost_lines: PackedStringArray = [
	"You're like a warm beer... Disappointing, but I love it.",
	"I think you should grind some money and scraps now. Let me know when you have 200 of each, then we can talk shop.",
]
@export_multiline var won_lines: PackedStringArray = [
	"That's my boii.",
	"I think you should grind some money and scraps now. Let me know when you have 200 of each, then we can talk shop.",
]

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
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/talk_shop.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var won := String(Quests.notes.get(RACE_QUEST, "")) == "won"
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot, false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)

	await Cutscenes.subtitle(speaker_name, GRANDPA, ask_line, grandpa.actor)
	var player_name := PlayerProfile.display_name()
	if won:
		if player != null:
			Cutscenes.hop(player, 30.0)
		await Cutscenes.subtitle(player_name, PlayerProfile.character, player_won_line, player)
		if not Cutscenes.is_skipping():
			grandpa.hiccup()
		await Cutscenes.wait(0.4)
	else:
		await Cutscenes.subtitle(player_name, PlayerProfile.character, player_lost_line, player)
		if not Cutscenes.is_skipping():
			grandpa.sip(-8.0)
		await Cutscenes.wait(1.4)
	for line in (won_lines if won else lost_lines):
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await Cutscenes.wait(0.4)
