class_name CoinsCutscene
extends Cutscene
## The staging "Ask Around" scenes share (FarmerCoinsCutscene,
## SmithCoinsCutscene): the player hops out of the car and walks up to an NPC
## who shows them some treasure coins, held up in a CoinCloseup to inspect.
## The NPC's own rig in the world hides while a CutsceneActor stands in for
## them, and comes back at the end.

const NICKEL := preload("res://scenes/items/icons/item_old_nickel.tscn")

@export_group("Staging")
@export var zoom: float = 1.6
@export var coin_zoom: float = 2.4
## Where the NPC holds a coin out, in their character space.
@export var coin_spot := Vector2(48.0, -150.0)

## Set before playing: the NPC's CharacterRig in the world.
var npc_rig: CharacterRig

var npc: CutsceneActor
var npc_name: String
var npc_data: CharacterData
var player: CutsceneActor
var me: CharacterData
var my_name: String
var two_shot: Vector2

## Walks the player up to the NPC. False if there's no NPC to talk to.
func stage() -> bool:
	if not is_instance_valid(npc_rig):
		return false
	npc_data = npc_rig.character_data
	npc_name = npc_data.display_name if npc_data != null else "?"
	me = PlayerProfile.character
	my_name = PlayerProfile.display_name()
	var at := npc_rig.global_position
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var from := car.global_position if car != null else at + Vector2(220.0, 20.0)
	var side := 1.0 if from.x > at.x else -1.0
	npc_rig.visible = false
	npc = Cutscenes.spawn_actor(npc_data, at, side > 0.0)
	if me != null:
		player = Cutscenes.spawn_actor(me, from + Vector2(-40.0 * side, 14.0), side < 0.0)
		Cutscenes.sound(&"door_close", -6.0)
	var meet := at + Vector2(130.0 * side, 6.0)
	two_shot = (meet + at) * 0.5 + Vector2(0.0, -110.0)
	Cutscenes.camera_to((from + at) * 0.5 + Vector2(0.0, -110.0), zoom - 0.3, 0.8)
	if player != null:
		await Cutscenes.walk(player, meet, 150.0)
		Cutscenes.face(player, side < 0.0)
	await Cutscenes.camera_to(two_shot, zoom, 0.6)
	return true

## The NPC holds a coin out, and the camera leans in on it.
func hold_out_coin() -> Node2D:
	var coin := NICKEL.instantiate() as Node2D
	coin.position = coin_spot
	coin.scale = Vector2.ONE * 0.7
	coin.z_index = GrandpaNpc.WRENCH_Z
	npc.attach(coin)
	await Cutscenes.camera_to(coin.global_position, coin_zoom, 0.5)
	return coin

func npc_says(line: String) -> void:
	await Cutscenes.subtitle(npc_name, npc_data, line, npc)

func i_say(line: String) -> void:
	await Cutscenes.subtitle(my_name, me, line, player)

## Puts the NPC's own rig back.
func unstage() -> void:
	if is_instance_valid(npc_rig):
		npc_rig.visible = true
