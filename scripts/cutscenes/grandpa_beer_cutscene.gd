class_name GrandpaBeerCutscene
extends Cutscene
## After "Downhill Billie (Again)": the player is back from the spike pit even
## bloodier, and Grandpa laughs so hard he cries. Through the tears he admits
## the wrench whack did absolutely nothing, and sends the player for beer
## with $40 (the quest's `start_money`). Unlocked by "Downhill Billie
## (Again)"; plays when the player talks to him while it's available
## (GrandpaNpc), and gives "Beer Run".
##
## The words live in res://cutscenes/grandpa_beer.tres; edit them in the
## inspector. The beats:
##   - the player's character stands by the car, beaten up worse (level 2)
##   - Grandpa cackles with tears rolling, then blurts the `confession_lines`
##     still tearing up
##   - one more laugh, then the `errand_lines`

const ID := &"grandpa_beer"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
## Blurted through tears. These defaults are the scene as written; edits in
## the inspector on the .tres override them.
@export_multiline var confession_lines: PackedStringArray = [
	"I DID ABSOLUTELY NOTHING WHEN I HIT THAT CAR WITH MY WRENCH!",
]
@export_multiline var errand_lines: PackedStringArray = [
	"Go to the shop, get yourself and myself some beer.",
]

@export_group("Staging")
## Where the player's own character stands, relative to their car.
@export var player_offset := Vector2(5.0, -25.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
@export var laugh_seconds: float = 3.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/beer_run.tres")

func play() -> void:
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null or not is_instance_valid(grandpa):
		return
	var middle := (car.global_position + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, car.global_position + player_offset,
				car.global_position.x < grandpa.global_position.x)
		CharacterInjuries.apply(player, 2)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.wait(0.5)

	await _laugh(laugh_seconds, -1.0, &"grandpa_cackle", 6.0)
	for line in confession_lines:
		if not Cutscenes.is_skipping():
			grandpa.tear_up(4)
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await _laugh(1.4, -4.0, &"grandpa_laugh", 0.0)
	for line in errand_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await Cutscenes.wait(0.4)

## Laughing with tears rolling, the camera rattling along when `shake` > 0.
func _laugh(seconds: float, volume_db: float, sound: StringName, shake: float) -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.laugh(seconds, volume_db, sound, true)
	if shake > 0.0:
		Cutscenes.shake(shake, seconds)
	await Cutscenes.wait(seconds + 0.3)
