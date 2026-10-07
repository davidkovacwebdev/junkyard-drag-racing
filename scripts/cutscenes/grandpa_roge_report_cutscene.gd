class_name GrandpaRogeReportCutscene
extends Cutscene
## Handing in "Sure Thing": Roge lost. Grandpa can't believe it, then asks
## what now, as if betting on Roge wasn't his idea. He wants to win it back;
## the player says no; he agrees. The quest's `turn_in_cutscene`; GrandpaNpc
## finishes the quest once it's over.
##
## Against all odds Roge might have won: then it's the short `won_chat`.
##
## The words live in res://cutscenes/grandpa_roge_report.tres; edit them in
## the inspector. In every list, a line starting with "> " is the player's.
## He has a fit at the line at `fit_at` and sighs before the one at
## `sigh_at` (in `lost_chat`).

const ID := &"grandpa_roge_report"
const QUEST_ID := &"roge_roger_bet"
const GRANDPA := preload("res://characters/grandpa.tres")
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var lost_chat: PackedStringArray = [
	"> Well, Roge lost...",
	"No way.",
	"> Way.",
	"What now?",
	"> I DUNNO, YOU TOLD ME TO BET ON HIM!",
	"Oh, right...",
	"WE NEED TO WIN IT BACK! GO AGAIN!",
	"> No.",
	"You're right.",
]
@export var fit_at: int = 6
@export var sigh_at: int = 8
@export_multiline var won_chat: PackedStringArray = [
	"> Roge won.",
	"Told ya. Sure thing. Now go get me my beer.",
]

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
@export var camera_lift: float = 70.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

var _player: CutsceneActor = null

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var won := String(Quests.notes.get(QUEST_ID, "")) == "won"
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

	var chat := won_chat if won else lost_chat
	for i in chat.size():
		if Cutscenes.is_skipping():
			break
		if not won and i == fit_at:
			grandpa.twitch(0.8, -3.0)
			Cutscenes.shake(6.0, 0.4)
		elif not won and i == sigh_at:
			grandpa.sigh()
			await Cutscenes.wait(1.2)
		await _say(chat[i])
	if won and not Cutscenes.is_skipping():
		grandpa.sip(-8.0)
	await Cutscenes.wait(0.6)

func _say(line: String) -> void:
	if line.begins_with(PLAYER_MARK):
		await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character,
				line.trim_prefix(PLAYER_MARK), _player)
	else:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
