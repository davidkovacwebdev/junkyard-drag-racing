class_name GrandpaHeliHomeCutscene
extends Cutscene
## "Up, Up and Away", handed in: back home, Grandpa's out of the car and in
## his chair, the helicopter engine and tail rotor unloaded in front of him,
## and he's over the moon. "I'll make something out of this, you watch."
## The quest's turn-in scene: HeliStory has GrandpaNpc hand it in as the car
## pulls up at home (or the player presses E there), which plays this and
## then takes the parts.
##
## The words live in res://cutscenes/grandpa_heli_home.tres; edit them in
## the inspector.

const ID := &"grandpa_heli_home"
const GRANDPA := preload("res://characters/grandpa.tres")
const ENGINE := preload("res://items/heli_engine.tres")
const ROTOR := preload("res://items/tail_rotor.tres")

@export var speaker_name: String = "Grandpa"
@export var look_line: String = "Hehehe! Look at 'em! An engine AND a propeller!"
@export var make_line: String = "I'll make something out of this, you watch."

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
@export var camera_lift: float = 70.0
## Where the two parts are set down, from Grandpa.
@export var engine_spot := Vector2(-125.0, -30.0)
@export var rotor_spot := Vector2(-215.0, -40.0)

## Set by GrandpaNpc before playing.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var player_spot := grandpa.global_position + player_offset
	await Cutscenes.fade_out(0.4)
	grandpa.park_car_for_scene()
	Cutscenes.sound(&"door_close", -6.0)
	await Cutscenes.wait(0.3)
	Cutscenes.sound(&"grandpa_heave", -6.0)
	grandpa.visible = true
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, player_spot, false)
		CharacterInjuries.apply(player, CharacterInjuries.current_level())
	Cutscenes.cut_to((player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift), zoom)
	await Cutscenes.wait(0.4)

	# Out of the trunk and down in front of him.
	Cutscenes.sound(&"trunk_open", -6.0)
	var props: Array[Node2D] = []
	props.append(_set_down(ENGINE, grandpa.global_position + engine_spot))
	props.append(_set_down(ROTOR, grandpa.global_position + rotor_spot))
	Cutscenes.sound(&"anvil_clang", -10.0)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.wait(0.3)

	if not Cutscenes.is_skipping():
		grandpa.laugh(1.6, -4.0, &"grandpa_laugh", true)
	await Cutscenes.wait(0.6)
	await _grandpa_says(look_line)
	if not Cutscenes.is_skipping():
		grandpa.wink()
	await _grandpa_says(make_line)
	await Cutscenes.wait(0.5)

	await Cutscenes.fade_out(0.5)
	for prop in props:
		if is_instance_valid(prop):
			prop.queue_free()

## The item's icon, propped on the ground at `at` for the scene.
func _set_down(item: ItemData, at: Vector2) -> Node2D:
	if item.icon_scene == null:
		return null
	var prop := item.icon_scene.instantiate() as Node2D
	prop.scale = Vector2.ONE * 1.4
	grandpa.get_parent().add_child(prop)
	prop.global_position = at
	return prop

func _grandpa_says(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
