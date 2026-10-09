class_name GrandpaGoneCutscene
extends Cutscene
## "Grandpa?", at the garage: the player climbs out by the garage door and
## calls for Grandpa. His spot is empty. They call again, louder. Nothing.
## Then their trashy old phone goes off: a squeaky voice from the hospital
## asks if this is Eugen's grandson, says Eugen died, and that he's at the
## hospital. Plays when the player presses E at the garage while the quest
## is on (GrandpasGarage), which finishes it once it's over.
##
## The words live in res://cutscenes/grandpa_gone.tres; edit them in the
## inspector.

const ID := &"grandpa_gone"
const CALLER := preload("res://characters/phone_caller.tres")
const PHONE := preload("res://scenes/characters/props/trashy_phone.tscn")

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var call_line: String = "Grandpa?"
@export var shout_line: String = "GRANDPA?!"
@export var ask_line: String = "Is this {player}, Eugen's grandson?"
@export var yes_line: String = "Yes?"
@export var news_line: String = "We're sorry to tell you that Eugen died."
@export var panic_line: String = "WHAT HAPPENED? WHERE IS HE?"
@export var hospital_line: String = "Sir, we're at the hospital."

@export_group("Staging")
@export var zoom: float = 1.5
@export var phone_zoom: float = 2.3
## Where the phone sits against the player's ear, in their character space.
@export var ear_spot := Vector2(30.0, -205.0)
## How long nobody answers, after each call.
@export var silence_seconds: float = 1.6

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
	var empty_spot := StoryDirector.GRANDPA_SPOT
	var name := PlayerProfile.display_name()
	var me := PlayerProfile.character

	Music.hush(true)
	await Cutscenes.fade_out(0.0)
	var player := Cutscenes.spawn_actor(me, start + Vector2(-70.0, 10.0), false)
	Cutscenes.cut_to(start + Vector2(-60.0, -120.0), zoom)
	await Cutscenes.fade_in(0.8)

	await Cutscenes.walk(player, door, 130.0)
	await Cutscenes.subtitle(name, me, call_line, player)
	# His spot by the door: no chair, no beer, nobody.
	Cutscenes.face(player, empty_spot.x > player.global_position.x)
	await Cutscenes.camera_to(empty_spot + Vector2(0.0, -110.0), zoom, 0.9)
	await Cutscenes.wait(silence_seconds)
	await Cutscenes.camera_to((empty_spot + door) * 0.5 + Vector2(0.0, -110.0), zoom, 0.6)
	Cutscenes.shake(5.0, 0.3)
	await Cutscenes.subtitle(name, me, shout_line, player)
	Cutscenes.sound(&"cricket_chirp", -10.0)
	await Cutscenes.wait(silence_seconds)

	# The phone.
	Cutscenes.sound(&"phone_ring", -3.0)
	await Cutscenes.hop(player, 30.0)
	await Cutscenes.wait(1.3)
	Cutscenes.sound(&"phone_ring", -3.0)
	await Cutscenes.camera_to(player.global_position + Vector2(0.0, -150.0), phone_zoom, 0.7)
	var phone := PHONE.instantiate() as Node2D
	phone.position = ear_spot
	phone.z_index = GrandpaNpc.WRENCH_Z
	player.attach(phone)
	Cutscenes.sound(&"phone_pickup", -4.0)
	await Cutscenes.wait(0.4)

	await Cutscenes.subtitle(CALLER.display_name, CALLER, ask_line)
	await Cutscenes.subtitle(name, me, yes_line, player)
	await Cutscenes.subtitle(CALLER.display_name, CALLER, news_line)
	await Cutscenes.wait(1.0)
	Cutscenes.shake(10.0, 0.5)
	await Cutscenes.subtitle(name, me, panic_line, player)
	await Cutscenes.subtitle(CALLER.display_name, CALLER, hospital_line)
	Cutscenes.sound(&"phone_pickup", -6.0)
	await Cutscenes.wait(0.8)
