class_name GrandpaPackageCutscene
extends Cutscene
## After "Safety Last": Grandpa's having a coffee for once, chilling. The
## player calls him Eugen, which only his son Chad gets away with, and out
## comes the family's shame: Chad's a cop. Then Grandpa remembers his
## package. In this town the garbage truck brings the mail (and the medicine,
## and the ambulance, and...), so the player has to go and get it off the
## truck. How? Improvise. Unlocked by "Safety Last"; plays when the player
## talks to him while it's available (GrandpaNpc), and gives "Special
## Delivery".
##
## The words live in res://cutscenes/grandpa_package.tres; edit them in the
## inspector. In every list, a line starting with "> " is the player's; any
## other is his. The beats:
##   - the player walks up while he slurps his coffee (the mug's in his hand
##     instead of the beer for the whole scene)
##   - the `eugen_chat`: his eyes pop wide at the name
##   - his `shout_line`, with a fit and a camera rattle
##   - the `truck_chat`, then each of the `afterthoughts` after a pause and
##     another slurp, as he keeps remembering what else the truck does
##   - the `errand_chat`

const ID := &"grandpa_package"
const GRANDPA := preload("res://characters/grandpa.tres")
const MUG := preload("res://scenes/characters/props/coffee_mug.tscn")
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var eugen_chat: PackedStringArray = [
	"> What's up, Eugen?",
	"Dontcha get cute with me. The only one who calls me that is your gay uncle Chad.",
	"> You have a gay brother?",
	"Yeah. Whole family was ashamed, so he moved to the next town over.",
	"> Ashamed of him being gay?",
	"HELL NAH. He's a dickhead.",
	"> A dickhead?",
	"Yee. A porkchop.",
	"> I don't follow.",
	"He's a donut patrol. A popo. Five-O. A baton diddler. A freakin' COP.",
	"> I wanna meet him.",
]
@export var shout_line: String = "WELL GO KICK A CAN THEN!"
@export_multiline var truck_chat: PackedStringArray = [
	"Anyways. There's a package that should've arrived. Have you seen a garbage truck?",
	"> It's been driving around... What's a garbage truck got to do with your package?",
	"Silly {player}, this is a small town. Same truck collects the garbage and handles the mail and packages...",
]
## Each one comes after a pause and a slurp of coffee.
@export_multiline var afterthoughts: PackedStringArray = [
	"...and handles medicine. And the ambulance.",
	"...and coroner services.",
	"...and during the Junkyard Festival, it's an ice-cream truck!",
]
@export_multiline var errand_chat: PackedStringArray = [
	"Anyways, go find that truck and get me my package.",
	"> How do I do that!?",
	"I dunno! Improvise!",
]

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
## The pause before each afterthought, as it slowly comes to him.
@export var afterthought_pause: float = 1.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

var _player: CutsceneActor = null

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/special_delivery.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	grandpa.hold_instead_of_beer(MUG.instantiate())
	if PlayerProfile.character != null:
		_player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	_slurp()
	if _player != null:
		await Cutscenes.walk(_player, player_spot, 120.0)
		Cutscenes.face(_player, false)
	await Cutscenes.wait(0.4)

	for i in eugen_chat.size():
		await _say(eugen_chat[i])
		# "Eugen" gets a jolt and wide eyes, right after the player says it.
		if i == 0 and not Cutscenes.is_skipping():
			grandpa.widen_eyes(1.2)
			await Cutscenes.wait(0.5)

	if not Cutscenes.is_skipping():
		grandpa.twitch(0.8, -3.0)
		Cutscenes.shake(6.0, 0.4)
	await _say(shout_line)
	await Cutscenes.wait(0.6)

	for line in truck_chat:
		await _say(line)
	for line in afterthoughts:
		await Cutscenes.wait(afterthought_pause)
		_slurp()
		await Cutscenes.wait(1.0)
		await _say(line)

	for line in errand_chat:
		await _say(line)
	_slurp()
	await Cutscenes.wait(0.8)
	grandpa.hold_instead_of_beer(null)

func _slurp() -> void:
	if not Cutscenes.is_skipping():
		grandpa.sip(-8.0, &"coffee_slurp")

## A line from either of them: "> " marks the player's.
func _say(line: String) -> void:
	if line.begins_with(PLAYER_MARK):
		await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character,
				line.trim_prefix(PLAYER_MARK), _player)
	else:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
