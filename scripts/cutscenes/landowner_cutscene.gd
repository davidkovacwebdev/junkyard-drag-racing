class_name LandownerCutscene
extends Cutscene
## Fishing too long in one spot: Clyde comes tearing up in his white pickup,
## leans out of the window and runs the player off his land. The player gets
## out to talk to him, gets yelled at, and Clyde peels off again. Played by
## PlayerCar once the line's been in long enough (`fishing_patience`), which
## reels the line in first.
##
## The words live in res://cutscenes/landowner.tres; edit them in the
## inspector.

const ID := &"landowner"
const CLYDE := preload("res://characters/landowner_clyde.tres")

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var who_line: String = "Who told you you could fish here?"
@export var thought_line: String = "Uh, I thought it was state property."
@export var state_line: String = "State?!"
@export var yeah_line: String = "Yeah."
@export var this_line: String = "This?!"
@export var hey_line: String = "Hey..."
@export var road_line: String = "Hit the road, dude! This ain't no state property. This is private property!"

@export_group("Staging")
@export var zoom: float = 1.4
## How far from the car the truck pulls up, and how far off it comes from.
@export var park_gap: float = 420.0
@export var drive_from: float = 1700.0
@export var drive_in_seconds: float = 2.2

## Set by PlayerCar: where the line was in, so the truck comes from the
## other side, off the land.
var water_at: Vector2

func _init() -> void:
	id = ID

func play() -> void:
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null:
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var at := car.global_position
	var side := -1.0 if water_at.x > at.x else 1.0
	var park := at + Vector2(side * park_gap, 26.0)
	var clyde := CLYDE.display_name

	Cutscenes.camera_to(at + Vector2(side * park_gap * 0.5, -110.0), zoom - 0.3, 1.0)
	var truck := PickupTruck.spawn(car.get_parent(), park + Vector2(side * drive_from, 0.0), side < 0.0, CLYDE)
	await Cutscenes.play_tween(truck.drive_to(park, drive_in_seconds))
	Cutscenes.sound(&"pickup_skid", -4.0)
	Cutscenes.shake(6.0, 0.25)

	# Out of the car to see who it is.
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, at + Vector2(side * 90.0, 16.0), side > 0.0)
		Cutscenes.sound(&"door_close", -6.0)
		await Cutscenes.walk(player, at + Vector2(side * 150.0, 18.0), 140.0)
	var two_shot := (at + park) * 0.5 + Vector2(side * 30.0, -110.0)
	await Cutscenes.camera_to(two_shot, zoom, 0.7)
	var him := truck.driver

	await Cutscenes.subtitle(clyde, CLYDE, who_line, him)
	await Cutscenes.subtitle(my_name, me, thought_line, player)
	await _shout(clyde, state_line, him)
	await Cutscenes.subtitle(my_name, me, yeah_line, player)
	await _shout(clyde, this_line, him)
	await Cutscenes.subtitle(my_name, me, yeah_line, player)
	await _shout(clyde, state_line, him)
	await Cutscenes.subtitle(my_name, me, hey_line, player)
	Cutscenes.shake(10.0, 0.4)
	await Cutscenes.subtitle(clyde, CLYDE, road_line, him)

	# Back in the car; he peels off.
	if player != null:
		await Cutscenes.walk(player, at + Vector2(side * 60.0, 16.0), 200.0)
		player.visible = false
		Cutscenes.sound(&"door_close", -6.0)
	Cutscenes.sound(&"truck_honk", -6.0)
	truck.face(side > 0.0)
	await Cutscenes.play_tween(truck.drive_to(park + Vector2(side * drive_from, 0.0), 1.6))
	truck.queue_free()

## Clyde can't believe his ears: he jumps in his seat, and the camera jolts.
func _shout(speaker: String, line: String, actor: CutsceneActor) -> void:
	Cutscenes.shake(7.0, 0.25)
	Cutscenes.hop(actor, 12.0)
	await Cutscenes.subtitle(speaker, CLYDE, line, actor)
