class_name ChadReportCutscene
extends Cutscene
## "Weekend's Over": two days after the fake gold, the player calls on Chad at
## his house to swap notes. What happens depends on whether Gus has been
## caught yet (TreasureStory.gus_caught()):
##
## - Caught: the player fills Chad in. Gus from the forge found a piece of the
##   real treasure, made fakes to cash in on it and planted them around, and
##   told the player where he found the real piece. The player shows Chad the
##   spot on the map (ChadNpc opens the map after the scene), and they head
##   out there together ("The Dig Site").
## - Not caught: Chad starts in on his weekend with his husband (with a
##   wink, wink), the player cuts him off, he puckers up and blows them a
##   kiss, then gets to it, a fake coin in hand:
##   freshly smelted, bumpy where the mould was off, a snapped-off pour spout
##   on every rim. Somebody with a forge. "You do have a smithy... let's go."
##   ChadNpc hands out "Strike While It's Hot" through `gives_quest`.
##
## Played by ChadNpc. The words live in res://cutscenes/chad_report.tres;
## edit them in the inspector. `{player}` becomes the player's name, `{smith}`
## the smith's.

const ID := &"chad_report"
const NICKEL := preload("res://scenes/items/icons/item_old_nickel.tscn")
const SMITH := preload("res://characters/smith.tres")
const SMITH_TOKEN := "{smith}"

@export_group("Gus caught")
@export var asked_line: String = "So, I asked around.. Long story short, {smith} who works in the smithy found a part of the original treasure."
@export var profit_line: String = "He wanted to profit on it, so he made fake treasure and spread it around the area. However, he told me where he found the original part."
@export var map_card: String = "Treasure Area Spot"

@export_group("Gus loose")
@export var weekend_line: String = "Okay so, after the long, loong, looooong weekend I had with my housband..."
@export var skip_line: String = "Please skip the informalities."
@export var shy_line: String = "Aww, are you shyy?"
@export var smelted_line: String = "Anyways, these fake coins seem to be recently smelted, judging by the metal surface and polishing."
@export var bumpy_line: String = "See how the flat parts are bumpy? That means the mold wasn't perfect."
@export var spout_line: String = "Also, if you look at the rim, each fake coin has a visible indicator the pour spout was snapped off."
@export var next_line: String = "So, any idea where to look next?"
@export var smithy_line: String = "Well, you do have a smithy. I'd check there, so let's go."

@export_group("Staging")
@export var zoom: float = 1.6
@export var coin_zoom: float = 2.6
## Where Chad holds the fake coin up, in his character space.
@export var coin_spot := Vector2(44.0, -150.0)

## Set by ChadNpc before playing.
var chad: ChadNpc
var gus_caught := false

var _me: CharacterData
var _my_name: String
var _player: CutsceneActor

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(chad):
		return
	_me = PlayerProfile.character
	_my_name = PlayerProfile.display_name()
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var from := car.global_position if car != null else chad.global_position + Vector2(200.0, 30.0)
	var side := 1.0 if from.x > chad.global_position.x else -1.0
	if _me != null:
		_player = Cutscenes.spawn_actor(_me, from + Vector2(-50.0 * side, 14.0), side < 0.0)
		Cutscenes.sound(&"door_close", -6.0)
	var meet := chad.global_position + Vector2(130.0 * side, 10.0)
	var two_shot := (meet + chad.global_position) * 0.5 + Vector2(0.0, -110.0)
	Cutscenes.camera_to((from + chad.global_position) * 0.5 + Vector2(0.0, -110.0), zoom - 0.3, 0.8)
	if _player != null:
		await Cutscenes.walk(_player, meet, 140.0)
		Cutscenes.face(_player, side < 0.0)
	Cutscenes.face(chad.actor, side > 0.0)
	await Cutscenes.camera_to(two_shot, zoom, 0.7)

	if gus_caught:
		await _fill_chad_in()
	else:
		await _chads_findings(two_shot)
	await _ride_along(from, side)

func _fill_chad_in() -> void:
	await _i_say(asked_line)
	await _i_say(profit_line)
	# Out comes the map, the spot Gus marked on it.
	Cutscenes.sound(&"paper_unfold", -4.0)
	if _player != null:
		Cutscenes.hop(_player, 10.0)
	await Cutscenes.title_card(map_card, 1.6)

func _chads_findings(two_shot: Vector2) -> void:
	await _chad_says(weekend_line)
	# Wink, wink.
	await _wink_wink()
	await _i_say(skip_line)
	chad.actor.blush(2.5)
	await _chad_says(shy_line)
	await _smooch()

	# A fake coin in his hand, the camera in close on it.
	var coin := NICKEL.instantiate() as Node2D
	coin.position = coin_spot
	coin.z_index = GrandpaNpc.WRENCH_Z
	chad.actor.attach(coin)
	Cutscenes.sound(&"fake_gold_knock", -8.0)
	await Cutscenes.camera_to(coin.global_position, coin_zoom, 0.6)
	await _chad_says(smelted_line)
	await _chad_says(bumpy_line)
	await _chad_says(spout_line)
	await Cutscenes.camera_to(two_shot, zoom, 0.6)
	if is_instance_valid(coin):
		coin.queue_free()
	await _i_say(next_line)
	await _chad_says(smithy_line)

func _wink_wink() -> void:
	if Cutscenes.is_skipping():
		return
	Cutscenes.face(chad.actor, _player == null or _player.global_position.x > chad.global_position.x)
	chad.actor.wink(-6.0)
	await Cutscenes.wait(0.75)
	chad.actor.wink(-8.0)
	await Cutscenes.wait(0.75)

## He puckers up and blows the player a kiss: a smooch and a heart floating
## over to them.
func _smooch() -> void:
	if Cutscenes.is_skipping():
		return
	chad.actor.pucker(0.9)
	Cutscenes.hop(chad.actor, 12.0)
	Cutscenes.sound(&"flag_kiss", -4.0, chad.actor)
	var lips := chad.actor.global_position + Vector2(0.0, -110.0)
	var to := _player.global_position + Vector2(0.0, -110.0) if _player != null else lips
	GrandpaDragQueenCutscene.pop_heart(lips.lerp(to, 0.5))
	await Cutscenes.wait(1.0)

## Off to the car, the two of them. Chad rides along, so his house stands
## empty till they're done at the forge or the dig site (ChadNpc).
func _ride_along(car_at: Vector2, side: float) -> void:
	chad.visible = false
	var walker := Cutscenes.spawn_actor(chad.character_data, chad.global_position, side > 0.0)
	if _player != null:
		Cutscenes.walk(_player, car_at + Vector2(-40.0 * side, 14.0), 170.0)
	await Cutscenes.walk(walker, car_at + Vector2(40.0 * side, 18.0), 170.0)
	Cutscenes.sound(&"door_close", -6.0)
	await Cutscenes.wait(0.2)
	Cutscenes.sound(&"door_close", -8.0)
	await Cutscenes.fade_out(0.5)

func _chad_says(line: String) -> void:
	await Cutscenes.subtitle(chad.display_name, chad.character_data, line, chad.actor)

func _i_say(line: String) -> void:
	await Cutscenes.subtitle(_my_name, _me, line.replace(SMITH_TOKEN, SMITH.display_name), _player)
