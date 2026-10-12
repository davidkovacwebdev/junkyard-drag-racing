class_name PoliceFineCutscene
extends Cutscene
## Honking outside the hospital (HospitalQuietZone): the police come wailing
## up in a garbage truck (the town's one emergency vehicle), two officers get
## out, point at the "no honking" sign the player drove right past, and write
## them a fine. A player who can't cover it hands over whatever they've got.
## Then they drive off again.
##
## With the shop's Super Horn on the car they're furious: they skid up with
## the sirens going, yell every line, kick the car, and the fine is tripled.
##
## The words live in res://cutscenes/police_fine.tres; edit them in the
## inspector.

const ID := &"police_fine"
const DALE := preload("res://characters/officer_dale.tres")
const RITA := preload("res://characters/officer_rita.tres")
const FINE_TOKEN := "{fine}"

@export var fine: int = 50
## The Super Horn fine is this many times `fine`.
@export var angry_multiplier: int = 3

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var zone_line: String = "This is a hospital zone. Did you not see the sign?"
@export var what_sign_line: String = "What sign?"
@export var that_sign_line: String = "That sign."
@export var fine_line: String = "Honking at a hospital. That's a ${fine} fine."
@export var paid_line: String = "Pleasure doing business."
@export var broke_line: String = "Broke, huh? We'll take what you've got."
@export var quiet_line: String = "Now keep it down. People are dying in there."

@export_group("Angry (Super Horn)")
@export var angry_zone_line: String = "HEY! THIS IS A HOSPITAL ZONE! WHAT IS WRONG WITH YOU?!"
@export var angry_that_sign_line: String = "THAT SIGN! THE BIG ONE! RIGHT THERE!"
@export var angry_fine_line: String = "With THAT horn? Windows rattled on the third floor. Triple fine. ${fine}."
@export var angry_paid_line: String = "And get that thing off your car before we do it for you."
@export var angry_broke_line: String = "Empty your pockets. ALL of it."
@export var angry_quiet_line: String = "People are DYING in there! Some of them because of YOU!"

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
	var angry := Inventory.has_item(PlayerCar.SUPER_HORN)
	var amount := fine * (angry_multiplier if angry else 1)
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
	var drive_in := drive_in_seconds * (0.6 if angry else 1.0)
	_sirens(5 if angry else 3, drive_in / (5.0 if angry else 3.0))
	await Cutscenes.play_tween(truck.drive_to(park, drive_in))
	truck.global_position = park
	if angry:
		Cutscenes.sound(&"pickup_skid", -2.0)
		Cutscenes.shake(10.0, 0.3)
	Cutscenes.sound(&"door_close", -6.0)
	var cab := park + Vector2(330.0, 0.0)
	var dale := Cutscenes.spawn_actor(DALE, cab + Vector2(10.0, 18.0), true)
	var rita := Cutscenes.spawn_actor(RITA, cab + Vector2(-20.0, -8.0), true)
	Cutscenes.walk(rita, at + Vector2(-240.0, -6.0), 150.0)
	await Cutscenes.walk(dale, at + Vector2(-170.0, 18.0), 150.0)
	await Cutscenes.camera_to(at + Vector2(-150.0, -110.0), zoom, 0.8)

	if angry:
		_yell(dale)
	await Cutscenes.subtitle(DALE.display_name, DALE, angry_zone_line if angry else zone_line, dale)
	await Cutscenes.subtitle(my_name, me, what_sign_line, player)
	if sign_node != null:
		Cutscenes.face(rita, sign_node.global_position.x > rita.global_position.x)
	if angry:
		_yell(rita)
	await Cutscenes.subtitle(RITA.display_name, RITA, angry_that_sign_line if angry else that_sign_line, rita)
	if sign_node != null:
		await Cutscenes.camera_to(sign_node.global_position + Vector2(0.0, -110.0), sign_zoom, 1.0)
		await Cutscenes.wait(1.2)
		await Cutscenes.camera_to(at + Vector2(-150.0, -110.0), zoom, 0.9)
	Cutscenes.face(rita, true)

	if angry:
		# Rita gives the car a kick on the way past.
		await Cutscenes.walk(rita, at + Vector2(-120.0, -10.0), 220.0)
		Cutscenes.sound(&"car_whack", -2.0)
		Cutscenes.shake(14.0, 0.35)
		Cutscenes.hop(rita, 20.0)
		await Cutscenes.wait(0.4)
		_yell(dale)
	await Cutscenes.subtitle(DALE.display_name, DALE,
			(angry_fine_line if angry else fine_line).replace(FINE_TOKEN, str(amount)), dale)
	var paid := mini(amount, Inventory.money)
	Inventory.spend_money(paid)
	if paid > 0:
		Cutscenes.sound(&"cash_register", -4.0)
	if paid >= amount:
		await Cutscenes.subtitle(DALE.display_name, DALE, angry_paid_line if angry else paid_line, dale)
	else:
		await Cutscenes.subtitle(RITA.display_name, RITA, angry_broke_line if angry else broke_line, rita)
	if angry:
		_yell(rita)
	await Cutscenes.subtitle(RITA.display_name, RITA, angry_quiet_line if angry else quiet_line, rita)

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

## An officer losing it: a hop and a camera jolt as they start yelling.
func _yell(officer: CutsceneActor) -> void:
	Cutscenes.hop(officer, 26.0)
	Cutscenes.shake(8.0, 0.25)

## `count` siren whoops, `gap` seconds apart, without holding the scene up.
func _sirens(count: int, gap: float) -> void:
	for i in count:
		Cutscenes.sound(&"siren_whoop", -4.0)
		await Cutscenes.wait(gap)
