class_name DigSiteCutscene
extends Cutscene
## "The Dig Site": the player and Chad pull up at the X Gus marked west of the
## docks. Digging up the whole acre is a non-starter, so Chad rings his
## husband: declined, he's busy. A moment later Chad's own phone goes off,
## blaring "Bonk Club" (the race chant, SongLibrary). He answers a bit sheepishly and coos down the phone,
## hips swaying, while a tiny "mi mi mimimi" answers from the other end. The
## upshot: they need a metal detector. Where from? Chad hasn't a clue. Played
## once by TreasureStory when the car reaches the spot, which finishes the
## quest.
##
## The words live in res://cutscenes/dig_site.tres; edit them in the
## inspector.

const ID := &"dig_site"
const CHAD := preload("res://characters/chad.tres")
## His ringtone: the baked race song, from the top.
const RINGTONE_SONG := &"bonk_club"
const RINGTONE_DB := -4.0

@export var dig_line: String = "I guess we need to dig now."
@export var acre_line: String = "You're gonna dig the entire acre?"
@export var better_line: String = "Have any better idea?"
@export var hubby_line: String = "Lemme call my hubby bubby."
@export var busy_line: String = "I think he's busy.. oh well."
@export var hey_line: String = "Heyy hubbyy, soooo we found this treasure site and we want to diiig, what do you suggest?"
## Chad's half of the call, each answered with a "mi mi mimimi".
@export var call_lines: PackedStringArray = [
	"Okay?",
	"Okay? Where do we get that?",
	"Okay? Thankss, love ya.",
]
@export var detector_line: String = "Soo, our best bet is finding a metal detector."
@export var where_line: String = "Where do I find that?"
@export var beats_me_line: String = "Beats me."
@export var bye_line: String = "Let me know when you find the treasure, hehe."

@export_group("Staging")
@export var zoom: float = 1.6
## How long his phone rings before he gives in and answers.
@export var ring_seconds: float = 4.0
## The quiet after the declined call, before his own phone goes.
@export var lull_seconds: float = 2.0

var _me: CharacterData
var _my_name: String
var _player: CutsceneActor
var _chad: CutsceneActor

func _init() -> void:
	id = ID

func play() -> void:
	_me = PlayerProfile.character
	_my_name = PlayerProfile.display_name()
	var spot := TreasureDigSpot.SPOT
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var from := car.global_position if car != null else spot + Vector2(260.0, 20.0)
	var side := 1.0 if from.x > spot.x else -1.0
	if _me != null:
		_player = Cutscenes.spawn_actor(_me, from + Vector2(-40.0 * side, 14.0), side < 0.0)
		Cutscenes.sound(&"door_close", -6.0)
	_chad = Cutscenes.spawn_actor(CHAD, from + Vector2(30.0 * side, 26.0), side < 0.0)
	Cutscenes.sound(&"door_close", -8.0)
	var player_spot := spot + Vector2(150.0 * side, 0.0)
	var chad_spot := spot + Vector2(270.0 * side, 10.0)
	var two_shot := (player_spot + chad_spot) * 0.5 + Vector2(0.0, -110.0)
	Cutscenes.camera_to((from + spot) * 0.5 + Vector2(0.0, -110.0), zoom - 0.3, 0.8)
	if _player != null:
		Cutscenes.walk(_player, player_spot, 150.0)
	await Cutscenes.walk(_chad, chad_spot, 150.0)
	await Cutscenes.camera_to(two_shot, zoom, 0.6)
	# The player looks the patch over, then turns to Chad.
	if _player != null:
		Cutscenes.face(_player, side < 0.0)
	await _i_say(dig_line)
	_face_each_other()
	await _chad_says(acre_line)
	await _i_say(better_line)

	# He rings his husband...
	await _chad_says(hubby_line)
	Cutscenes.sound(&"cute_coo", -6.0, _chad)
	_chad.blush(1.5)
	await Cutscenes.wait(0.5)
	await _phone(true)
	await _sound_for(&"phone_dial", -8.0, 3.4)
	# ...who declines.
	await _sound_for(&"phone_busy", -8.0, 1.0)
	await _phone(false)
	await _chad_says(busy_line)

	# Then his own phone goes off. Loudly.
	await Cutscenes.wait(lull_seconds)
	var ringtone := _start_ringtone()
	Cutscenes.hop(_chad, 18.0)
	if _player != null:
		Cutscenes.hop(_player, 10.0)
	await Cutscenes.wait(ring_seconds)
	if is_instance_valid(ringtone):
		ringtone.queue_free()
	Music.hush(false)
	# He answers, red to the ears about the ringtone.
	Cutscenes.sound(&"phone_beep", -8.0)
	_chad.blush(3.0)
	await _phone(true)
	_chad.swaying = true
	await _chad_says(hey_line)
	await _sound_for(&"phone_mimimi", -4.0, 1.3)
	for i in call_lines.size():
		await _chad_says(call_lines[i])
		if i < call_lines.size() - 1:
			await _sound_for(&"phone_mimimi", -4.0, 1.3)
	# A smooch down the line, and he hangs up.
	_chad.pucker(0.8)
	Cutscenes.sound(&"flag_kiss", -4.0, _chad)
	await Cutscenes.wait(0.9)
	Cutscenes.sound(&"phone_beep", -8.0)
	_chad.swaying = false
	await _phone(false)
	_face_each_other()

	await _chad_says(detector_line)
	await _i_say(where_line)
	await _chad_says(beats_me_line)
	_chad.wink(-6.0)
	await Cutscenes.wait(0.7)
	await _chad_says(bye_line)

	# Off he goes, home.
	Cutscenes.face(_chad, side > 0.0)
	await Cutscenes.walk(_chad, chad_spot + Vector2(500.0 * side, 0.0), 220.0)
	await Cutscenes.fade_out(0.5)

func _face_each_other() -> void:
	if _player != null:
		Cutscenes.face(_player, _chad.global_position.x > _player.global_position.x)
		Cutscenes.face(_chad, _player.global_position.x > _chad.global_position.x)

## Chad's phone up to his ear, or away again.
func _phone(up: bool) -> void:
	if Cutscenes.is_skipping():
		_chad.hold_phone(up, 0.01)
		return
	await Cutscenes.play_tween(_chad.hold_phone(up))

## Plays a sound and waits about as long as it lasts.
func _sound_for(sound_name: StringName, volume_db: float, seconds: float) -> void:
	Cutscenes.sound(sound_name, volume_db, _chad)
	await Cutscenes.wait(seconds)

## Chad's phone going off: the music ducks out and "Bonk Club" plays from
## the top until he answers (null while skipping).
func _start_ringtone() -> AudioStreamPlayer:
	if Cutscenes.is_skipping():
		return null
	var stream := load(SongLibrary.baked_path(RINGTONE_SONG)) as AudioStream
	if stream == null:
		return null
	Music.hush(true, 0.3)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = RINGTONE_DB
	Cutscenes.get_tree().current_scene.add_child(player)
	player.play()
	return player

func _chad_says(line: String) -> void:
	await Cutscenes.subtitle(CHAD.display_name, CHAD, line, _chad)

func _i_say(line: String) -> void:
	await Cutscenes.subtitle(_my_name, _me, line, _player)
