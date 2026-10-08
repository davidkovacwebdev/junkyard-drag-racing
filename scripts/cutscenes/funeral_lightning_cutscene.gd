class_name FuneralLightningCutscene
extends Cutscene
## The player missed Grandpa's funeral. The sky goes quiet, a bolt of
## lightning comes down on the car (charring it black), Grandpa yells from
## above, and it's YOU DIED. Played by the Funeral autoload when the time to
## get to the graveyard runs out; it winds the story back once this ends.
## Works without a car too (in a shop, say): then it's just the flash, the
## voice and the card.
##
## The words live in res://cutscenes/funeral_lightning.tres; edit them in
## the inspector.

const ID := &"funeral_lightning"
const GRANDPA := preload("res://characters/grandpa.tres")
const BOLT_COLOR := Color(1.0, 0.96, 0.7, 1)
const CHARRED := Color(0.18, 0.17, 0.17, 1)

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var speaker_name: String = "Grandpa (from above)"
@export var angry_line: String = "YOU MISSED MY FUNERAL, {player}?!"
@export var died_line: String = "YOU DIED"

@export_group("Staging")
@export var zoom: float = 1.6
## How high above the car the bolt starts.
@export var bolt_height: float = 900.0

func _init() -> void:
	id = ID

func play() -> void:
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	Music.hush(true, 0.3)
	if car != null:
		await Cutscenes.camera_to(car.global_position + Vector2(0.0, -100.0), zoom, 0.6)
	await Cutscenes.wait(0.8)

	# The strike.
	var bolt: Polygon2D = null
	if car != null:
		bolt = _make_bolt()
		car.get_parent().add_child(bolt)
		bolt.global_position = car.global_position
	if not Cutscenes.is_skipping():
		Funeral.flash()
	Cutscenes.sound(&"lightning_strike", 0.0)
	Cutscenes.shake(22.0, 0.7)
	if car != null:
		car.modulate = CHARRED
	await Cutscenes.wait(0.6)
	if is_instance_valid(bolt):
		bolt.queue_free()
	await Cutscenes.wait(1.0)

	Cutscenes.sound(&"grandpa_twitch", -2.0)
	await Cutscenes.subtitle(speaker_name, GRANDPA, angry_line)
	await Cutscenes.title_card(died_line, 2.2)
	Funeral.cover()

## A fat zigzag from high above down to the car, five chunky legs.
func _make_bolt() -> Polygon2D:
	var bolt := Polygon2D.new()
	bolt.color = BOLT_COLOR
	bolt.z_index = 50
	var h := bolt_height
	bolt.polygon = PackedVector2Array([
		Vector2(-30.0, -h), Vector2(20.0, -h), Vector2(-10.0, -h * 0.62), Vector2(40.0, -h * 0.6),
		Vector2(-6.0, -h * 0.26), Vector2(34.0, -h * 0.25), Vector2(0.0, 0.0),
		Vector2(-4.0, -h * 0.2), Vector2(-42.0, -h * 0.21), Vector2(-2.0, -h * 0.55),
		Vector2(-52.0, -h * 0.57),
	])
	return bolt
