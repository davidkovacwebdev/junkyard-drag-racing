class_name PoliceFineCutscene
extends Cutscene
## Honking outside the hospital (HospitalQuietZone): the police come wailing
## up in a garbage truck (the town's one emergency vehicle), two officers get
## out, point at the "no honking" sign the player drove right past, and write
## them a fine. A player who can't cover it hands over whatever they've got.
## Then they drive off again.
##
## The words live in res://cutscenes/police_fine.tres; edit them in the
## inspector.

const ID := &"police_fine"
const DALE := preload("res://characters/officer_dale.tres")
const RITA := preload("res://characters/officer_rita.tres")
const FINE_TOKEN := "{fine}"

@export var fine: int = 50

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var zone_line: String = "This is a hospital zone. Did you not see the sign?"
@export var what_sign_line: String = "What sign?"
@export var that_sign_line: String = "That sign."
@export var fine_line: String = "Honking at a hospital. That's a ${fine} fine."
@export var paid_line: String = "Pleasure doing business."
@export var broke_line: String = "Broke, huh? We'll take what you've got."
@export var quiet_line: String = "Now keep it down. People are dying in there."

@export_group("Staging")
@export var zoom: float = 1.3
@export var sign_zoom: float = 1.8
@export var truck_scale: float = 0.8
@export var drive_in_seconds: float = 2.6

## Set by HospitalQuietZone before playing.
var sign_node: Node2D

func _init() -> void:
	id = ID

func play() -> void:
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null:
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var at := car.global_position
	# Where the truck's back end stops: far enough back that its cab (the
	# truck's origin is its rear) ends well short of the officers.
	var park := at + Vector2(-860.0, 0.0)

	# Out of the car to see what all the noise is.
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, at + Vector2(-70.0, 16.0), false)
		Cutscenes.sound(&"door_close", -6.0)
	Cutscenes.camera_to(at + Vector2(-380.0, -90.0), zoom - 0.4, 1.0)

	# Here they come, siren whooping.
	var truck := PenGarbageTruck.spawn(car.get_parent(), at + Vector2(-1700.0, 0.0), true)
	truck.scale = Vector2.ONE * truck_scale
	_sirens(3, drive_in_seconds / 3.0)
	await Cutscenes.play_tween(truck.drive_to(park, drive_in_seconds))
	truck.global_position = park
	Cutscenes.sound(&"door_close", -6.0)
	var cab := park + Vector2(330.0, 0.0)
	var dale := Cutscenes.spawn_actor(DALE, cab + Vector2(10.0, 18.0), true)
	var rita := Cutscenes.spawn_actor(RITA, cab + Vector2(-20.0, -8.0), true)
	Cutscenes.walk(rita, at + Vector2(-240.0, -6.0), 150.0)
	await Cutscenes.walk(dale, at + Vector2(-170.0, 18.0), 150.0)
	await Cutscenes.camera_to(at + Vector2(-150.0, -110.0), zoom, 0.8)

	await Cutscenes.subtitle(DALE.display_name, DALE, zone_line, dale)
	await Cutscenes.subtitle(my_name, me, what_sign_line, player)
	if sign_node != null:
		Cutscenes.face(rita, sign_node.global_position.x > rita.global_position.x)
	await Cutscenes.subtitle(RITA.display_name, RITA, that_sign_line, rita)
	if sign_node != null:
		await Cutscenes.camera_to(sign_node.global_position + Vector2(0.0, -110.0), sign_zoom, 1.0)
		await Cutscenes.wait(1.2)
		await Cutscenes.camera_to(at + Vector2(-150.0, -110.0), zoom, 0.9)
	Cutscenes.face(rita, true)

	await Cutscenes.subtitle(DALE.display_name, DALE, fine_line.replace(FINE_TOKEN, str(fine)), dale)
	var paid := mini(fine, Inventory.money)
	Inventory.spend_money(paid)
	if paid > 0:
		Cutscenes.sound(&"cash_register", -4.0)
	if paid >= fine:
		await Cutscenes.subtitle(DALE.display_name, DALE, paid_line, dale)
	else:
		await Cutscenes.subtitle(RITA.display_name, RITA, broke_line, rita)
	await Cutscenes.subtitle(RITA.display_name, RITA, quiet_line, rita)

	# Back in the truck and away.
	Cutscenes.walk(rita, cab + Vector2(-20.0, -8.0), 170.0)
	await Cutscenes.walk(dale, cab + Vector2(10.0, 18.0), 170.0)
	dale.visible = false
	rita.visible = false
	Cutscenes.sound(&"door_close", -6.0)
	truck.face(false)
	_sirens(2, 0.9)
	await Cutscenes.play_tween(truck.drive_to(park + Vector2(-1500.0, 0.0), 2.2))
	truck.queue_free()
	SaveSystem.save_game()

## `count` siren whoops, `gap` seconds apart, without holding the scene up.
func _sirens(count: int, gap: float) -> void:
	for i in count:
		Cutscenes.sound(&"siren_whoop", -4.0)
		await Cutscenes.wait(gap)
