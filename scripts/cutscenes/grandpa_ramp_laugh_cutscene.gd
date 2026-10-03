class_name GrandpaRampLaughCutscene
extends Cutscene
## After "Downhill Billie": the player limps back from the spike pit bruised
## and bloody, and Grandpa laughs his head off. Then he whacks the player's
## car with his new wrench and swears it'll work now. Unlocked by
## "Downhill Billie"; plays when the player talks to him while it's available
## (GrandpaNpc), and gives "Downhill Billie (Again)".
##
## The words live in res://cutscenes/grandpa_ramp_laugh.tres; edit them in the
## inspector. The beats:
##   - the player's character stands by the car, beaten up (level 1)
##   - Grandpa laughs loudly, then says the `laugh_lines`
##   - he wheels himself over to the car, whacks it with the straight wrench
##     (the camera jolts), wheels back and says the `after_whack_lines`

const ID := &"grandpa_ramp_laugh"
const GRANDPA := preload("res://characters/grandpa.tres")

@export var speaker_name: String = "Grandpa"
## Said once he's done laughing. These defaults are the scene as written;
## edits in the inspector on the .tres override them.
@export_multiline var laugh_lines: PackedStringArray = [
	"I guess you'll need a better vehicle.",
	"For now, let me just do this...",
]
@export_multiline var after_whack_lines: PackedStringArray = [
	"Try it now, it should work.",
]

@export_group("Staging")
## Where the player's own character stands, relative to their car.
@export var player_offset := Vector2(5.0, -25.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
@export var laugh_seconds: float = 2.2
## How far from the car's middle he parks his wheelchair to whack it, and
## how far behind (up-screen of) it, so the car draws in front of him.
@export var whack_reach: float = 70.0
@export var whack_behind: float = 12.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/ramp_again.tres")

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
		CharacterInjuries.apply(player, 1)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.wait(0.5)

	await _laugh()
	for line in laugh_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await _whack(car)
	for line in after_whack_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await Cutscenes.wait(0.4)

func _laugh() -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.laugh(laugh_seconds, -3.0)
	await Cutscenes.wait(laugh_seconds + 0.3)

## He rolls up to the car, the new wrench comes down on it (a hollow bong
## off the panel), and he rolls back.
func _whack(car: Node2D) -> void:
	if Cutscenes.is_skipping():
		return
	var side := signf(grandpa.global_position.x - car.global_position.x)
	if side == 0.0:
		side = 1.0
	var spot := car.global_position + Vector2(side * whack_reach, -whack_behind)
	grandpa.roll_to(spot - grandpa.global_position)
	await Cutscenes.wait(0.9)
	grandpa.face_wrench_toward(car.global_position)
	await Cutscenes.wait(0.15)
	grandpa.bang(-8.0, true)
	await Cutscenes.wait(0.21)
	Cutscenes.sound(&"car_whack", -2.0, car)
	Cutscenes.shake(10.0, 0.3)
	await Cutscenes.wait(0.7)
	grandpa.roll_to(Vector2.ZERO)
	await Cutscenes.wait(0.9)
