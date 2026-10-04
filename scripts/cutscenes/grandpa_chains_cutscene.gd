class_name GrandpaChainsCutscene
extends Cutscene
## After "Pay Your Respects": there's a new thing in town, a hill climbing
## race, and Grandpa wants in. But first he needs chains, so he sends the
## player to the Shop for some. Unlocked by "Pay Your Respects"; plays when
## the player talks to him while it's available (GrandpaNpc), and gives
## "Chains".
##
## The words live in res://cutscenes/grandpa_chains.tres; edit them in the
## inspector. The beats:
##   - the player walks up while he takes a sip, and he says the `news_lines`
##   - his eyes pop for the `chains_line`
##   - he sends the player off with the `errand_lines`

const ID := &"grandpa_chains"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var news_lines: PackedStringArray = [
	"Ok, there's a new thing in town. Could be worth checkin' out.",
	"It's a hill climbing race...",
]
## Said with his eyes popping.
@export var chains_line: String = "...but first we need to get the chains!"
@export_multiline var errand_lines: PackedStringArray = [
	"Go buy some chains and come back here so I can set everything up.",
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
	gives_quest = preload("res://quests/chain_gang.tres")

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
	await Cutscenes.fade_in(0.8)
	if not Cutscenes.is_skipping():
		grandpa.sip(-8.0)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)
	await Cutscenes.wait(0.4)

	for line in news_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	if not Cutscenes.is_skipping():
		grandpa.widen_eyes(1.8)
	await Cutscenes.subtitle(speaker_name, GRANDPA, chains_line, grandpa.actor)
	for line in errand_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await Cutscenes.wait(0.4)
