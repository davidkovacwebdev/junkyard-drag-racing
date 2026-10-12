class_name NightDiggerCutscene
extends Cutscene
## "Graveyard Shift" ends: the masked digger's pickup breaks down after the
## player's rams. Out climb a man in a welding mask and his kid. He flips the
## mask up: it's Gus the smith. He's the one planting fake treasure, to put
## the town on the map, and he wanted to make a splash with the one real coin
## he found (as a race prize, for a fee). Threatened with Chad's baton, he
## marks where he found it on the player's map (TreasureDigSpot), west of the
## docks. Finishes "Graveyard Shift" if the beggar gave it ("Ask Around" goes
## on until the player reports to Chad, see ChadReportCutscene). Played by
## NightDiggerTruck.
##
## The words live in res://cutscenes/night_digger.tres.

const ID := &"night_digger"
const MASKED := preload("res://characters/gus_masked.tres")
const GUS := preload("res://characters/smith.tres")
const KID := preload("res://characters/gus_kid.tres")

@export var aggressive_line: String = "WHY SO AGGRESSIVE?!"
@export var caught_line: String = "So you've been wandering around and planting fake treasure."
@export var so_what_line: String = "SOO WHAT? I'm not the first nor the last who tried using the treasure to promote and improve this town."
@export var keep_line: String = "Yeah, but you wanted to keep something for yourself, no?"
@export var bite_me_line: String = "Oh, bite me. I found one original coin and I wanted to make a big splash out of it by making it a reward... I also wanted some money, but WHO CAN BLAME ME?"
@export var where_line: String = "Where did you get the original part?"
@export var not_saying_line: String = "I'm not saying."
@export var baton_line: String = "I'll call my grandpa's gay brother. He has a large baton, you see."
@export var alright_line: String = "Alright, alright! I found it west of the docks... Here, let me mark it on your map."
@export var nothing_line: String = "I was unable to find anything there ever since..."
@export var marked_card: String = "Treasure Area Spot marked on your map"

@export_group("Staging")
@export var zoom: float = 1.5
@export var kid_scale: float = 0.72

## Set by NightDiggerTruck before playing.
var truck: NightDiggerTruck

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(truck):
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var at := truck.global_position
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var from := car.global_position if car != null else at + Vector2(300.0, 20.0)
	var side := 1.0 if from.x > at.x else -1.0
	var gus_at := at + Vector2(70.0 * side, 16.0)
	Cutscenes.camera_to(at + Vector2(0.0, -100.0), zoom - 0.3, 0.8)
	await Cutscenes.wait(0.6)

	# Doors: the masked man and his kid climb out.
	Cutscenes.sound(&"door_close", -6.0)
	var gus := Cutscenes.spawn_actor(MASKED, gus_at, side > 0.0)
	await Cutscenes.wait(0.3)
	Cutscenes.sound(&"door_close", -8.0)
	var kid := Cutscenes.spawn_actor(KID, at + Vector2(-60.0 * side, 20.0), side > 0.0)
	kid.scale = Vector2.ONE * kid_scale
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, from + Vector2(-40.0 * side, 14.0), side < 0.0)
		Cutscenes.sound(&"door_close", -6.0)
	var meet := gus_at + Vector2(140.0 * side, 0.0)
	var two_shot := (meet + gus_at) * 0.5 + Vector2(0.0, -110.0)
	Cutscenes.camera_to(two_shot, zoom, 0.8)
	Cutscenes.hop(gus, 26.0)
	await Cutscenes.subtitle("Masked Man", MASKED, aggressive_line, gus)
	if player != null:
		await Cutscenes.walk(player, meet, 170.0)
		Cutscenes.face(player, side < 0.0)

	# He flips the mask up: Gus.
	Cutscenes.sound(&"wrench_clunk", -8.0)
	var unmasked := Cutscenes.spawn_actor(GUS, gus.global_position, side > 0.0)
	gus.queue_free()
	gus = unmasked
	var gus_name := GUS.display_name
	await Cutscenes.wait(0.5)

	await Cutscenes.subtitle(my_name, me, caught_line, player)
	await Cutscenes.subtitle(gus_name, GUS, so_what_line, gus)
	await Cutscenes.subtitle(my_name, me, keep_line, player)
	await Cutscenes.subtitle(gus_name, GUS, bite_me_line, gus)
	await Cutscenes.subtitle(my_name, me, where_line, player)
	await Cutscenes.subtitle(gus_name, GUS, not_saying_line, gus)
	await Cutscenes.subtitle(my_name, me, baton_line, player)
	Cutscenes.hop(kid, 18.0)
	await Cutscenes.subtitle(gus_name, GUS, alright_line, gus)

	Cutscenes.sound(&"paper_unfold", -4.0)
	TreasureDigSpot.place(truck.get_parent())
	await Cutscenes.title_card(marked_card, 2.0)
	await Cutscenes.subtitle(gus_name, GUS, nothing_line, gus)
	await Cutscenes.wait(0.5)

	# They pile back in and limp off into the dark.
	await Cutscenes.fade_out(0.6)
	if is_instance_valid(truck):
		truck.queue_free()
	Quests.complete(NightDiggerTruck.QUEST.id)
