class_name GrandpaHelmetCutscene
extends Cutscene
## After "King of the Hill": a new rally track has opened, and Grandpa hands
## the player his precious helmet. It's an old football helmet. He never
## cared about safety, and still doesn't: it's meant to be a wheel. Unlocked
## by "King of the Hill"; plays when the player talks to him while it's
## available (GrandpaNpc), puts the helmet in the garage's spare parts as a
## wheel and gives "Safety Last".
##
## The words live in res://cutscenes/grandpa_helmet.tres; edit them in the
## inspector. The beats:
##   - the player walks up while he takes a sip, and he says the `gift_lines`
##   - the helmet is jammed down over the player's head (`helmet_bwomp`) and
##     its part card pops up, like a part the crane hauls in
##   - back and forth through the `chat`
##   - a long pause, the player's blank `stare_line`, then their `name_line`
##     and his `name_answer`

const ID := &"grandpa_helmet"
const GRANDPA := preload("res://characters/grandpa.tres")
const HELMET_WHEEL := "res://scenes/parts/wheels/wheel_helmet.tscn"
## In `chat`, a line starting with this is the player's; any other is his.
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var gift_lines: PackedStringArray = [
	"My son, I've used this for years.",
	"I've heard a new rally track opened. You can use this.",
]
## The back and forth that follows. Lines starting with "> " are the
## player's; the rest are his.
@export_multiline var chat: PackedStringArray = [
	"> But Gramps, you never cared about the safety.",
	"Safety? I still don't care about the safety.",
	"> But why the helmet?",
	"Well, you can use it as your wheel, of course.",
]
## Said after a long pause, before the `name_line`.
@export var stare_line: String = ".............."
@export var name_line: String = "Is your name really Eugen?"
@export var name_answer: String = "Yes."

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
## Where the helmet wheel sits on the player, in their character space: down
## over their head, with just the chin showing.
@export var helmet_spot := Vector2(4.0, -222.0)
@export var helmet_scale: float = 1.25
## The player's long, blank stare before asking his name.
@export var pause_seconds: float = 1.8

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/rally_debut.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	if not Cutscenes.is_skipping():
		grandpa.sip(-8.0)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)
	await Cutscenes.wait(0.4)

	for line in gift_lines:
		await _grandpa(line)
	# Given even on a skip, so the garage always ends up with it.
	var helmet := helmet_part()
	Inventory.add_part(helmet)
	_wear_helmet(player)
	Cutscenes.sound(&"helmet_bwomp", -4.0)
	Cutscenes.shake(4.0, 0.25)
	await Cutscenes.wait(0.3)
	Cutscenes.sound(&"part_pickup", -6.0)
	await Cutscenes.part_card(helmet)

	for line in chat:
		if line.begins_with(PLAYER_MARK):
			await _player(line.trim_prefix(PLAYER_MARK), player)
		else:
			await _grandpa(line)

	await Cutscenes.wait(pause_seconds)
	await _player(stare_line, player)
	await _player(name_line, player)
	await _grandpa(name_answer)
	if not Cutscenes.is_skipping():
		grandpa.sip(-8.0)
	await Cutscenes.wait(0.6)

## The catalog's helmet wheel (with its tier ranked, for the card's tape).
static func helmet_part() -> PartData:
	for wheel: PartData in PartDatabase.wheels:
		if wheel.scene_path == HELMET_WHEEL:
			return wheel
	return PartDatabase.load_part_data(HELMET_WHEEL)

## The helmet goes on over the player's head for the rest of the scene.
func _wear_helmet(player: CutsceneActor) -> void:
	if player == null or Cutscenes.is_skipping():
		return
	player.attach(helmet_prop(helmet_spot, helmet_scale))

## The helmet wheel's own polygons, without its physics body, for a
## character to wear at `spot` (their character space).
static func helmet_prop(spot: Vector2, prop_scale: float) -> Node2D:
	var wheel := (load(HELMET_WHEEL) as PackedScene).instantiate()
	var helmet := Node2D.new()
	for child in wheel.get_children():
		if child is Polygon2D:
			helmet.add_child(child.duplicate())
	wheel.free()
	helmet.position = spot
	helmet.scale = Vector2.ONE * prop_scale
	helmet.z_index = 10
	return helmet

func _grandpa(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)

func _player(line: String, player: CutsceneActor) -> void:
	await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character, line, player)
