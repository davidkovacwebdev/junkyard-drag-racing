class_name GrandpaTigerCutscene
extends Cutscene
## Handing in "Giddy Up": the player brings the horse home. It walks up to
## Grandpa's chair and he's happy for once. He names it Tiger. Then he wants
## carrots for Tiger and, for some reason, black and orange paint. "To paint
## the fence." There is no fence. The quest's `turn_in_cutscene`; GrandpaNpc
## finishes the quest once it's over, which takes the horse off the player
## and hands out "Shopping for Tiger".
##
## The words live in res://cutscenes/grandpa_tiger.tres; edit them in the
## inspector. In every list, a line starting with "> " is the player's. The
## beats:
##   - Tiger walks in and neighs; Grandpa laughs
##   - the `naming_chat`
##   - the `errand_chat`; the player squints at him, doubtful, from the line
##     at `doubt_from` on
##   - his `shout_line`, with a fit and a camera rattle

const ID := &"grandpa_tiger"
const GRANDPA := preload("res://characters/grandpa.tres")
const SQUINT_EYES := preload("res://scenes/characters/parts/eyes/eyes_squint.tscn")
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var naming_chat: PackedStringArray = [
	"Atta boyyy! I'll name this horse...",
	"Tiger.",
	"> Tiger?",
	"Yeah. Somethin' wrong?",
	"> No...",
]
@export_multiline var errand_chat: PackedStringArray = [
	"Okay. Go get Tiger some carrots.",
	"Oh, and also. Also. Go buy me some black and orange paint.",
	"> Eugen... what for?",
	"I just wanna paint the fence, of course.",
	"> We don't have a fence.",
]
## Index into `errand_chat` of the line the player's doubt shows on.
@export var doubt_from: int = 2
@export var shout_line: String = "WELL THEN YOU'LL GO GET A FENCE ONCE YOU GET ME MY PAINT AND CARROTS!"

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.7
@export var camera_lift: float = 70.0
## Where Tiger walks in from, relative to its own spot, and how long it takes.
@export var tiger_from := Vector2(-420.0, 30.0)
@export var tiger_walk_seconds: float = 2.4

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

var _player: CutsceneActor = null

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var tiger := grandpa.tiger
	# Framed to fit all three: Tiger, Grandpa and the player.
	var middle := (player_spot + tiger.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	if PlayerProfile.character != null:
		_player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	if _player != null:
		await Cutscenes.walk(_player, player_spot, 120.0)
		Cutscenes.face(_player, false)
	Cutscenes.sound(&"horse_neigh", -4.0)
	await Cutscenes.play_tween(tiger.walk_in(tiger.global_position + tiger_from, tiger_walk_seconds))
	if not Cutscenes.is_skipping():
		grandpa.laugh(1.2, -4.0)
	await Cutscenes.wait(1.4)

	for line in naming_chat:
		await _say(line)
	for i in errand_chat.size():
		if i == doubt_from:
			_squint(_player)
		await _say(errand_chat[i])
	if not Cutscenes.is_skipping():
		grandpa.twitch(0.8, -3.0)
		Cutscenes.shake(6.0, 0.4)
	await _say(shout_line)
	await Cutscenes.wait(0.6)

## The player's eyes narrow: swapped for the squinting pair for the rest of
## the scene.
static func _squint(player: CutsceneActor) -> void:
	if player == null or Cutscenes.is_skipping():
		return
	var eyes := player.find_child("EyesPart", true, false) as Node2D
	if eyes == null:
		return
	var squint := SQUINT_EYES.instantiate() as Node2D
	eyes.get_parent().add_child(squint)
	squint.transform = eyes.transform
	squint.z_index = eyes.z_index
	eyes.visible = false

func _say(line: String) -> void:
	if line.begins_with(PLAYER_MARK):
		await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character,
				line.trim_prefix(PLAYER_MARK), _player)
	else:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
