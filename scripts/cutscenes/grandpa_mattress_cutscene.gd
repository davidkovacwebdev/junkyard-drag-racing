class_name GrandpaMattressCutscene
extends Cutscene
## "Under the Mattress", at the garage: the player climbs out, goes in, and
## (in the dark) turns Grandpa's mattress over, rummaging about. They come
## back out holding the old nickel his note was on about, and read its
## inscription. Plays when the player presses E at the garage while the
## quest is on (GrandpasGarage), which then puts the nickel in the trunk.
##
## The words live in res://cutscenes/grandpa_mattress.tres; edit them in the
## inspector.

const ID := &"grandpa_mattress"
const NICKEL := preload("res://scenes/items/icons/item_old_nickel.tscn")

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var found_line: String = "Under the mattress... an old nickel."
@export var inscription_line: String = "\"This is not part of the treasure.\" Huh."

@export_group("Staging")
@export var zoom: float = 1.6
@export var close_zoom: float = 2.3
## Where the nickel sits in the player's hand, in their character space.
@export var hand_spot := Vector2(44.0, -112.0)

## Set by GrandpasGarage before playing.
var garage: Node2D

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(garage) or PlayerProfile.character == null:
		return
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var start := car.global_position if car != null else garage.global_position + Vector2(50.0, 150.0)
	var door := Vector2(start.x, garage.global_position.y + 20.0)
	var name := PlayerProfile.display_name()
	var me := PlayerProfile.character

	await Cutscenes.fade_out(0.0)
	var player := Cutscenes.spawn_actor(me, start + Vector2(-70.0, 10.0), false)
	Cutscenes.cut_to(start + Vector2(-60.0, -120.0), zoom)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.walk(player, door, 130.0)

	# Inside, in the dark: the mattress flipped over and a good rummage.
	Cutscenes.sound(&"door_close", -4.0)
	await Cutscenes.fade_out(0.5)
	player.visible = false
	await Cutscenes.wait(0.5)
	Cutscenes.sound(&"mattress_squish", -4.0)
	await Cutscenes.wait(0.6)
	Cutscenes.sound(&"trash_rummage", -4.0)
	await Cutscenes.wait(1.0)
	Cutscenes.sound(&"mattress_squish", -6.0)
	await Cutscenes.wait(0.7)
	Cutscenes.sound(&"door_close", -6.0)

	# Back out, nickel in hand.
	player.visible = true
	Cutscenes.face(player, true)
	var nickel := NICKEL.instantiate() as Node2D
	nickel.scale = Vector2.ONE * 0.6
	nickel.position = hand_spot
	nickel.z_index = GrandpaNpc.WRENCH_Z
	player.attach(nickel)
	Cutscenes.cut_to(player.global_position + Vector2(20.0, -140.0), close_zoom)
	await Cutscenes.fade_in(0.5)
	Cutscenes.sound(&"wink_ting", -6.0)
	await Cutscenes.hop(player, 20.0)
	await Cutscenes.subtitle(name, me, found_line, player)
	await Cutscenes.subtitle(name, me, inscription_line, player)
	await Cutscenes.wait(0.5)
