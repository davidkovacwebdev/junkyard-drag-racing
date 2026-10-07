class_name GrandpaPackageReportCutscene
extends Cutscene
## Handing in "Special Delivery": Grandpa tears open the package the player
## knocked off the garbage truck, and it's a six-pack. Then he hands over a
## roll of bubble wrap (`accessory_bubble_wrap`, into the spare parts, with
## its part card) and sends the player to the Demolition Derby. The quest's
## `turn_in_cutscene`; GrandpaNpc finishes the quest once it's over, and its
## follow-up "Wrap It Up" opens the Derby.
##
## The words live in res://cutscenes/grandpa_package_report.tres; edit them
## in the inspector. In `chat`, a line starting with "> " is the player's.
## The beats:
##   - the box sits in his lap; he rips it open (`tape_rip`) and a six-pack
##     pops out of it
##   - the player's `beer_line`, his `gift_line` and the bubble wrap's card
##   - the rest of the `chat`

const ID := &"grandpa_package_report"
const GRANDPA := preload("res://characters/grandpa.tres")
const BOX := preload("res://scenes/items/icons/item_package.tscn")
const SIX_PACK := preload("res://scenes/items/icons/item_six_pack.tscn")
const BUBBLE_WRAP := "res://scenes/parts/accessories/accessory_bubble_wrap.tscn"
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var beer_line: String = "You ordered BEER like that!?"
@export var gift_line: String = "Shut the fuck up. Here's a bubble wrap for you."
@export_multiline var chat: PackedStringArray = [
	"> A bubble wrap?",
	"MAN, you're always so confused. Wrap your car up and go do the derby. Go make Gramps proud.",
]

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
## Where the box sits, relative to Grandpa: in his lap.
@export var lap_offset := Vector2(0.0, -62.0)
@export var box_scale: float = 0.6

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

var _player: CutsceneActor = null

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	if PlayerProfile.character != null:
		_player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	var box := _prop(BOX)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	if _player != null:
		await Cutscenes.walk(_player, player_spot, 120.0)
		Cutscenes.face(_player, false)
	await Cutscenes.wait(0.5)

	await _rip_open(box)
	await _say("> " + beer_line)
	await _say(gift_line)
	# Given even on a skip, so the garage always ends up with it.
	var wrap := bubble_wrap_part()
	Inventory.add_part(wrap)
	Cutscenes.sound(&"bubble_pop", -4.0)
	await Cutscenes.wait(0.2)
	Cutscenes.sound(&"part_pickup", -6.0)
	await Cutscenes.part_card(wrap)
	for line in chat:
		await _say(line)
	await Cutscenes.wait(0.6)

## The catalog's bubble wrap (with its tier ranked, for the card's tape).
static func bubble_wrap_part() -> PartData:
	for accessory: PartData in PartDatabase.accessories:
		if accessory.scene_path == BUBBLE_WRAP:
			return accessory
	return PartDatabase.load_part_data(BUBBLE_WRAP)

## The box shakes as he tears at the tape, then gives way: the six-pack
## pops up out of it.
func _rip_open(box: Node2D) -> void:
	if Cutscenes.is_skipping():
		return
	Cutscenes.sound(&"tape_rip", -4.0)
	var shake := box.create_tween()
	for i in 6:
		shake.tween_property(box, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.06)
	shake.tween_property(box, "rotation", 0.0, 0.06)
	await Cutscenes.play_tween(shake)
	Cutscenes.sound(&"cardboard_crumple", -4.0)
	var beer := _prop(SIX_PACK)
	beer.scale = Vector2.ONE * box_scale * 0.3
	var pop := beer.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(beer, "global_position:y", beer.global_position.y - 22.0, 0.35)
	pop.parallel().tween_property(beer, "scale", Vector2.ONE * box_scale, 0.35)
	box.queue_free()
	await Cutscenes.play_tween(pop)
	Cutscenes.sound(&"beer_crack", -8.0)
	await Cutscenes.wait(0.5)

## An item icon sat in Grandpa's lap, in front of him, gone with the scene.
func _prop(scene: PackedScene) -> Node2D:
	var prop := scene.instantiate() as Node2D
	prop.scale = Vector2.ONE * box_scale
	prop.z_index = 10
	grandpa.get_parent().add_child(prop)
	prop.global_position = grandpa.global_position + lap_offset
	Cutscenes.finished.connect(prop.queue_free, CONNECT_ONE_SHOT)
	return prop

## A line from either of them: "> " marks the player's.
func _say(line: String) -> void:
	if line.begins_with(PLAYER_MARK):
		await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character,
				line.trim_prefix(PLAYER_MARK), _player)
	else:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
