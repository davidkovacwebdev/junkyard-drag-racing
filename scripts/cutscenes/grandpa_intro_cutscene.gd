class_name GrandpaIntroCutscene
extends Cutscene
## Grandpa's wrench quest: he's trying to fix his busted wheelchair by
## whacking it with a bent wrench, raging, and sends the player off to find a
## better one. Unlocked by the scraps quest; plays when the player talks to
## him while it's available (GrandpaNpc), and gives "The Better Wrench".
##
## The words live in res://cutscenes/grandpa_intro.tres — open it and edit
## `lines` in the inspector. The scene's beats hang off the lines:
##   - three clangs, then the first line, then a harder clang with a jolt
##   - any line with {player} in it makes the player's character jump
##   - one last clang after the final line

const ID := &"grandpa_intro"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
## What Grandpa says, in order, one subtitle per entry. `{player}` becomes
## the player's name. These defaults are the scene as written; edits made in
## the inspector on the .tres override them.
@export_multiline var lines: PackedStringArray = [
	"Ever since that trash bag crushed my legs I can't do SHIT!",
	"{player}! Go get me the better wrench.",
	"This one's bent ever since I used it to hit that wench.",
	"You can find the new one under the bench.",
	"Or if it's not there... I dunno. Go find it!",
]

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa (the car
## could be parked anywhere nearby when the player takes this quest).
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads (and the flag) stay in frame.
@export var camera_lift: float = 70.0

## Set by StoryDirector before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/better_wrench.tres")

func play() -> void:
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null or not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot, false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)

	for i in 3:
		await _bang(-4.0)
	for i in lines.size():
		var line := lines[i]
		if player != null and line.contains(PlayerProfile.NAME_TOKEN):
			Cutscenes.hop(player, 24.0)
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
		if i == 0:
			await _bang(-2.0, 10.0)
	await _bang(-2.0, 8.0)
	await Cutscenes.wait(0.4)

## One whack at the car, with a camera jolt when `shake` is above zero.
func _bang(volume_db: float, shake: float = 0.0) -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.bang(volume_db)
	await Cutscenes.wait(0.21)
	if shake > 0.0:
		Cutscenes.shake(shake, 0.25)
	await Cutscenes.wait(0.35)
