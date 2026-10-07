class_name GrandpaHorseCutscene
extends Cutscene
## After "Wrap It Up": Grandpa's sad. Not crying, just sad: he's lonely, and
## the wheelchair sucks. He sends the player to the farm to buy him a horse
## (which is what gets the Farmer selling). Unlocked by "Wrap It Up"; plays
## when the player talks to him while it's available (GrandpaNpc), and gives
## "Giddy Up".
##
## The words live in res://cutscenes/grandpa_horse.tres; edit them in the
## inspector. In `chat`, a line starting with "> " is the player's. He sighs
## (sagging in his chair) before the lines in `sigh_before`.

const ID := &"grandpa_horse"
const GRANDPA := preload("res://characters/grandpa.tres")
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var chat: PackedStringArray = [
	"> What's up, Eugen?",
	"Go kiss your mother.",
	"> What's wrong, Gramps?",
	"I'm lonely. And using this wheelchair sucks.",
	"Go to the farm and buy me a horse.",
	"> Okay, I guess.",
]
## Indexes into `chat` of the lines he sighs before.
@export var sigh_before: PackedInt32Array = [1, 3]

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
@export var camera_lift: float = 70.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

var _player: CutsceneActor = null

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/horse_for_gramps.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	if PlayerProfile.character != null:
		_player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	if _player != null:
		await Cutscenes.walk(_player, player_spot, 120.0)
		Cutscenes.face(_player, false)
	await Cutscenes.wait(0.4)

	for i in chat.size():
		if sigh_before.has(i) and not Cutscenes.is_skipping():
			grandpa.sigh()
			await Cutscenes.wait(1.4)
		await _say(chat[i])
	await Cutscenes.wait(0.6)

func _say(line: String) -> void:
	if line.begins_with(PLAYER_MARK):
		await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character,
				line.trim_prefix(PLAYER_MARK), _player)
	else:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
