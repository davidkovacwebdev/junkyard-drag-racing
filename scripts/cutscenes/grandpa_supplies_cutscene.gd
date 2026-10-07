class_name GrandpaSuppliesCutscene
extends Cutscene
## Handing in "Shopping for Tiger": Grandpa takes the carrots and the paint,
## and now he wants the fence to paint. From where? A farm has one. The
## quest's `turn_in_cutscene`; GrandpaNpc finishes the quest once it's over,
## which hands out "Fenced In".
##
## The words live in res://cutscenes/grandpa_supplies.tres; edit them in the
## inspector. In `chat`, a line starting with "> " is the player's.

const ID := &"grandpa_supplies"
const GRANDPA := preload("res://characters/grandpa.tres")
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var chat: PackedStringArray = [
	"Great! Now go get me some fence.",
	"> Where would I do that?",
	"I dunno. I know a farm has one.",
]

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.7
@export var camera_lift: float = 70.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

var _player: CutsceneActor = null

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.tiger.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	if PlayerProfile.character != null:
		_player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	if _player != null:
		await Cutscenes.walk(_player, player_spot, 120.0)
		Cutscenes.face(_player, false)
	await Cutscenes.wait(0.3)
	# Handing the bag over: the carrots rustle, the paint can sloshes.
	Cutscenes.sound(&"carrot_crunch", -8.0)
	await Cutscenes.wait(0.3)
	Cutscenes.sound(&"paint_slosh", -4.0)
	await Cutscenes.wait(0.6)
	for line in chat:
		await _say(line)
	if not Cutscenes.is_skipping():
		grandpa.sip(-8.0)
	await Cutscenes.wait(0.6)

func _say(line: String) -> void:
	if line.begins_with(PLAYER_MARK):
		await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character,
				line.trim_prefix(PLAYER_MARK), _player)
	else:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
