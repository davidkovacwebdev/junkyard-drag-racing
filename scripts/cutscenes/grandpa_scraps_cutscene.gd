class_name GrandpaScrapsCutscene
extends Cutscene
## The opening scene, right after character creation: Grandpa is sitting by
## the car sipping his beer, gets halfway into a fond memory, then starts
## twitching and screaming for scrap. Gives the "gather scraps" quest.
##
## The words live in res://cutscenes/grandpa_scraps.tres; edit them in the
## inspector. The beats:
##   - he sips his beer, then says the `calm_lines`
##   - he starts twitching (camera rattles), then yells the `rant_lines`,
##     twitching again on each one
##   - the player's character jumps on any line with {player} in it

const ID := &"grandpa_scraps"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
## Said slowly and fondly, before the fit. These defaults are the scene as
## written; edits in the inspector on the .tres override them.
@export_multiline var calm_lines: PackedStringArray = [
	"Ah, what a nice day. It reminds me of how we star..",
]
## Yelled mid-fit.
@export_multiline var rant_lines: PackedStringArray = [
	"SCRAPS! SCRAPS! WE NEED SCRAPS!",
	"GO LOOT SOME DUMPSTERS!",
]

@export_group("Staging")
## Where the player's own character stands, relative to their car.
@export var player_offset := Vector2(5.0, -25.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads (and the flag) stay in frame.
@export var camera_lift: float = 70.0
@export var twitch_seconds: float = 1.2

## Set by StoryDirector before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/gather_scraps.tres")

func play() -> void:
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null or not is_instance_valid(grandpa):
		return
	var middle := (car.global_position + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, car.global_position + player_offset, false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(1.0)

	if not Cutscenes.is_skipping():
		grandpa.sip(-6.0)
	await Cutscenes.wait(1.4)
	for line in calm_lines:
		await _say(line, player)

	await _twitch(twitch_seconds, 10.0)
	for line in rant_lines:
		_twitch(twitch_seconds * 0.6, 6.0)
		await _say(line, player)
	await Cutscenes.wait(0.4)

func _say(line: String, player: CutsceneActor) -> void:
	if player != null and line.contains(PlayerProfile.NAME_TOKEN):
		Cutscenes.hop(player, 24.0)
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)

## A fit, with the camera rattling along.
func _twitch(seconds: float, shake: float) -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.twitch(seconds)
	Cutscenes.shake(shake, seconds)
	await Cutscenes.wait(seconds)
