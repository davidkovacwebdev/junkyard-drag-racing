class_name GoldFakeCutscene
extends Cutscene
## "Dig Deeper": the player has found the corner of gold under the crane pen's
## heap. They climb down out of the crane, and Chad comes walking in from the
## yard to have a look. He knocks on it, and hums and haws: it's a fake, just
## like the nickel. Somebody's planting fake treasure, but there's a real one
## out there too. The player flirts, Chad goes red, and he sends them off to
## snoop around town while he takes the fakes to his husband: meet in two
## days, he's off for the weekend. Played by CranePen when the gold is
## searched, before the quest is done.
##
## The words live in res://cutscenes/gold_fake.tres; edit them in the
## inspector. `{player}` becomes the player's name.

const ID := &"gold_fake"
const CHAD := preload("res://characters/chad.tres")

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var hmm_line: String = "Hmm.."
@export var fake_line: String = "Hmmmmmm, I think this one is fake as well.."
@export var look_line: String = "Look, this is not a real gold."
@export var planting_line: String = "It seems someone is placing these fake treasure bits..."
@export var real_treasure_line: String = "But we also know there's real treasure somewhere around here."
@export var boo_line: String = "You're the real treasure, boo."
@export var shy_line: String = "Shutthefuckup..."
@export var next_line: String = "Ok, so where do we go from here?"
@export var plan_line: String = "I'll go take these to my husband. Maybe he will be able to tell me more about this fake treasure."
@export var snoop_line: String = "You go around town and snoop around, ask around. Meet me in 2 days, I'm having a weekend out with my honey."

@export_group("Staging")
## The pen's own camera is pulled right back; this is close in on the gold.
@export var zoom: float = 1.1
@export var walk_speed: float = 260.0
## How far right of the gold Chad walks in from, and where he stops.
@export var enter_from: float = 1500.0
@export var stand_off: float = 90.0
## Where the player stands, right of Chad, having climbed down from the crane.
@export var player_off: float = 230.0
@export var blush_seconds: float = 3.5

## Set by CranePen before playing: the gold's spot on the pen floor, and the
## crane's cab, where the player climbs down.
var gold_at: Vector2
var cab_at: Vector2

func _init() -> void:
	id = ID

func play() -> void:
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var chad_name := CHAD.display_name
	var spot := gold_at + Vector2(stand_off, 0.0)
	var two_shot := gold_at + Vector2((stand_off + player_off) * 0.5, -120.0)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, cab_at, false)
		Cutscenes.sound(&"door_close", -6.0)
	var chad := Cutscenes.spawn_actor(CHAD, gold_at + Vector2(enter_from, 0.0), false)
	await Cutscenes.camera_to(two_shot, zoom, 0.8)
	if player != null:
		Cutscenes.walk(player, gold_at + Vector2(player_off, 0.0), walk_speed)
	await Cutscenes.walk(chad, spot, walk_speed)
	Cutscenes.face(chad, false)
	if player != null:
		Cutscenes.face(player, false)

	await Cutscenes.subtitle(chad_name, CHAD, hmm_line, chad)
	# A knock on it: hollow.
	await Cutscenes.hop(chad, 14.0)
	Cutscenes.sound(&"fake_gold_knock", -4.0)
	await Cutscenes.wait(0.4)
	await Cutscenes.subtitle(chad_name, CHAD, fake_line, chad)
	await Cutscenes.subtitle(chad_name, CHAD, look_line, chad)

	Cutscenes.face(chad, true)
	await Cutscenes.subtitle(chad_name, CHAD, planting_line, chad)
	await Cutscenes.subtitle(chad_name, CHAD, real_treasure_line, chad)
	await Cutscenes.subtitle(my_name, me, boo_line, player)
	# Chad goes red and looks away.
	chad.blush(blush_seconds)
	Cutscenes.sound(&"shy_blush", -6.0)
	Cutscenes.face(chad, false)
	await Cutscenes.wait(0.6)
	await Cutscenes.subtitle(chad_name, CHAD, shy_line, chad)
	Cutscenes.face(chad, true)
	await Cutscenes.subtitle(my_name, me, next_line, player)
	await Cutscenes.subtitle(chad_name, CHAD, plan_line, chad)
	await Cutscenes.subtitle(chad_name, CHAD, snoop_line, chad)

	# Off he goes for his weekend.
	await Cutscenes.walk(chad, gold_at + Vector2(enter_from * 0.6, 0.0), walk_speed * 1.3)
