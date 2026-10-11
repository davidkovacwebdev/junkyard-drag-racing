class_name ChadMeetCutscene
extends Cutscene
## "Over the Bridge": the player finally meets Chad, Grandpa's brother, the
## island's police officer, outside his house. He starts in on a warm welcome;
## the player cuts him off, only here about the Junkyard Treasure. After some
## back and forth (his sexuality, the player's views on the police, his
## archaeologist husband), he explains that fake treasure coins are going
## round, and the player's old nickel is one of them: "tresure", there's a
## typo. The real ones read "treasure", like Grandpa's note says. They agree
## to meet at the junkyard: once the crane's fixed, or right away if it
## already is. Played by ChadNpc the first time the player talks to him during
## the quest, which finishes it.
##
## The words live in res://cutscenes/chad_meet.tres; edit them in the
## inspector.

const ID := &"chad_meet"
const NICKEL := preload("res://scenes/items/icons/item_old_nickel.tscn")

## These defaults are the scene as written; edits in the inspector on the
## .tres override them. `{player}` becomes the player's name.
@export var welcome_line: String = "Hey {player}. I know we never met, but I want you to know, if you need anything, I'm..."
@export var interrupt_line: String = "No need for that."
@export var treasure_ask_line: String = "I just want to know more about the Junkyard Treasure. Grandpa said you knew something."
@export var sexuality_line: String = "You guys really have a problem with my sexuality..."
@export var pig_line: String = "No, you're just a pig. ACAB, 1312. Now tell me about the treasure."
@export var fair_line: String = "Fair enough, I guess... Well, my husband is an archaeologist..."
@export var gay_line: String = "Ha, gay."
@export var silence_line: String = "..."
@export var coins_line: String = "Anyway. He's been finding these coins, but some of them appear to be fake."
@export var misinformation_line: String = "Looks like someone's trying to spread misinformation about the treasure. Has Eugen found any coins?"
@export var here_line: String = "Yes, here's one."
@export var typo_line: String = "Yep, that one's fake. See? \"Tresure.\" There's a typo."
@export var found_line: String = "So Eugen found something at the junkyard?"
@export var died_line: String = "I guess he died trying to dig up something he found. Something gold, apparently."
## His last line: which one depends on whether the junkyard crane is back up.
@export var meet_later_line: String = "OK. Let's meet there once the crane is fixed."
@export var meet_now_line: String = "OK. Let's meet there now."

@export_group("Staging")
@export var zoom: float = 1.6
@export var coin_zoom: float = 2.6
## The awkward pause after "Ha, gay."
@export var silence_seconds: float = 1.4
## Where the player holds the nickel up, in their character space.
@export var coin_spot := Vector2(44.0, -150.0)

## Set by ChadNpc before playing.
var chad: ChadNpc

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(chad):
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var chad_name := chad.display_name
	var chad_data := chad.character_data
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var from := car.global_position if car != null else chad.global_position + Vector2(200.0, 30.0)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, from + Vector2(-50.0, 14.0), from.x < chad.global_position.x)
		Cutscenes.sound(&"door_close", -6.0)
	var side := 1.0 if from.x > chad.global_position.x else -1.0
	var meet := chad.global_position + Vector2(130.0 * side, 10.0)
	var two_shot := (meet + chad.global_position) * 0.5 + Vector2(0.0, -110.0)
	Cutscenes.camera_to((from + chad.global_position) * 0.5 + Vector2(0.0, -110.0), zoom - 0.3, 0.8)
	if player != null:
		await Cutscenes.walk(player, meet, 140.0)
		Cutscenes.face(player, chad.global_position.x > player.global_position.x)
	Cutscenes.face(chad.actor, player == null or player.global_position.x > chad.global_position.x)
	await Cutscenes.camera_to(two_shot, zoom, 0.7)

	await Cutscenes.subtitle(chad_name, chad_data, welcome_line, chad.actor)
	await Cutscenes.subtitle(my_name, me, interrupt_line, player)
	await Cutscenes.subtitle(my_name, me, treasure_ask_line, player)
	await Cutscenes.subtitle(chad_name, chad_data, sexuality_line, chad.actor)
	await Cutscenes.subtitle(my_name, me, pig_line, player)
	await Cutscenes.subtitle(chad_name, chad_data, fair_line, chad.actor)
	await Cutscenes.subtitle(my_name, me, gay_line, player)
	Cutscenes.sound(&"cricket_chirp", -10.0)
	await Cutscenes.subtitle(chad_name, chad_data, silence_line, chad.actor)
	await Cutscenes.wait(silence_seconds)
	await Cutscenes.subtitle(chad_name, chad_data, coins_line, chad.actor)
	await Cutscenes.subtitle(chad_name, chad_data, misinformation_line, chad.actor)

	# The player holds up Grandpa's nickel, and Chad spots the typo.
	var nickel: Node2D = null
	if player != null:
		nickel = NICKEL.instantiate() as Node2D
		nickel.position = coin_spot
		nickel.z_index = GrandpaNpc.WRENCH_Z
		player.attach(nickel)
	Cutscenes.sound(&"wink_ting", -8.0)
	await Cutscenes.subtitle(my_name, me, here_line, player)
	if nickel != null:
		await Cutscenes.camera_to(nickel.global_position, coin_zoom, 0.6)
	await Cutscenes.subtitle(chad_name, chad_data, typo_line, chad.actor)
	await Cutscenes.camera_to(two_shot, zoom, 0.6)
	if is_instance_valid(nickel):
		nickel.queue_free()

	await Cutscenes.subtitle(chad_name, chad_data, found_line, chad.actor)
	await Cutscenes.subtitle(my_name, me, died_line, player)
	await Cutscenes.subtitle(chad_name, chad_data,
			meet_later_line if CraneWreck.is_down() else meet_now_line, chad.actor)
	await Cutscenes.wait(0.5)
	Cutscenes.face(chad.actor, false)
