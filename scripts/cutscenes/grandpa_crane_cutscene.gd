class_name GrandpaCraneCutscene
extends Cutscene
## Grandpa's crane quest: the player finds him drunk and crying in his
## wheelchair, stuttering about how without his legs he can't feel the thrill
## of the crane any more. The player asks about the crane, he winks, and lets
## them in on his guy at the junkyard. Unlocked by "Grease Monkey"; plays when
## the player talks to him while it's available (GrandpaNpc), and gives
## "Claw Machine".
##
## The words live in res://cutscenes/grandpa_crane.tres; edit them in the
## inspector. The beats:
##   - he's mid-sob as the scene fades in, and sobs again after each `sob_lines`
##     line, with a hiccup in between
##   - the player's character steps up and asks the `player_line`
##   - he winks, then says the `wink_lines`

const ID := &"grandpa_crane"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
## Blubbered between sobs. These defaults are the scene as written; edits in
## the inspector on the .tres override them.
@export_multiline var sob_lines: PackedStringArray = [
	"*sniff* W-w-w... wh-why'd it have to be my l-l-legs...",
	"Wi-without my l-legs I c-c-can't feel the th-thrill of the c-c-crane no more... *hic*",
]
## What the player asks.
@export var player_line: String = "What about the crane?"
## Said with a wink, sobered up just enough.
@export_multiline var wink_lines: PackedStringArray = [
	"I know a guy at the crane. Vern. We ran that crane together for forty years.",
	"For 100 quids he'll let you use the crane like a claw machine. You know, to fish for parts?",
	"He'll let you keep the part. *hic*",
	"Here. A hundred quid, on me. Go fish ol' Grandpa somethin' nice.",
]

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
@export var sob_seconds: float = 1.3

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/crane_guy.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	_sob()
	await Cutscenes.fade_in(1.0)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)
	await Cutscenes.wait(0.3)

	for i in sob_lines.size():
		await Cutscenes.subtitle(speaker_name, GRANDPA, sob_lines[i], grandpa.actor)
		if i < sob_lines.size() - 1:
			await _hiccup()
		await _sob()

	await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character, player_line, player)
	await Cutscenes.wait(0.3)
	await _wink()
	for line in wink_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await _hiccup()
	await Cutscenes.wait(0.4)

func _sob() -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.sob(sob_seconds)
	await Cutscenes.wait(sob_seconds)

func _hiccup() -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.hiccup()
	await Cutscenes.wait(0.35)

func _wink() -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.wink()
	await Cutscenes.wait(0.9)
