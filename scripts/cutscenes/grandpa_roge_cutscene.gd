class_name GrandpaRogeCutscene
extends Cutscene
## After "Fenced In": Roge Roger is back in town (Grandpa gets the name the
## wrong way round first). A great racer, top division, almost as good as
## the Drag Queen. Grandpa doesn't want to watch him, he wants to bet on him,
## and hands over $100 (the quest's `start_money`) for a sure win and a lot
## of beer. Unlocked by "Fenced In"; plays when the player talks to him while
## it's available (GrandpaNpc), and gives "Sure Thing".
##
## The words live in res://cutscenes/grandpa_roge.tres; edit them in the
## inspector. In `chat`, a line starting with "> " is the player's. He
## twitches at the line at `correction_at` (getting the name straight) and
## cackles before the one at `cackle_at` (thinking of the beer).

const ID := &"grandpa_roge"
const GRANDPA := preload("res://characters/grandpa.tres")
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var chat: PackedStringArray = [
	"Roger Roge is back in town.",
	"> Who?",
	"Roger Roge.",
	"> Who's that?",
	"Roge.",
	"> Roge WHO?",
	"NO, Roge Roger.",
	"Anyway, he's a great racer. He's competing in the highest drag racing division. He's almost as good as the Drag Queen, although not as pretty...",
	"> So? Do you wanna watch Roge?",
	"Nah, but we can place a bet on him! Here's some money.",
	"It's a WIN, hehe. Imma get me so much beer.",
]
@export var correction_at: int = 6
@export var cackle_at: int = 10

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
	gives_quest = preload("res://quests/roge_roger_bet.tres")

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
		if Cutscenes.is_skipping():
			break
		if i == correction_at:
			grandpa.twitch(0.5, -6.0)
		elif i == cackle_at:
			grandpa.laugh(1.0, -4.0, &"grandpa_cackle")
			await Cutscenes.wait(0.8)
		await _say(chat[i])
	await Cutscenes.wait(0.5)

func _say(line: String) -> void:
	if line.begins_with(PLAYER_MARK):
		await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character,
				line.trim_prefix(PLAYER_MARK), _player)
	else:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
