class_name GrandpaRallyReportCutscene
extends Cutscene
## Handing in "Safety Last": the player comes back from the Rally wearing
## Grandpa's helmet. Won, and he says the `won_line`: safety is what lost the
## others the race. Lost, and he says the `lost_line` and yanks the helmet off
## their head. It leaves the spare parts, or the car it's fitted to, which
## gets a plain wheel in its place. The quest's `turn_in_cutscene`;
## GrandpaNpc finishes the quest once it's over.
##
## The words live in res://cutscenes/grandpa_rally_report.tres; edit them in
## the inspector.

const ID := &"grandpa_rally_report"
const QUEST_ID := &"rally_debut"
const GRANDPA := preload("res://characters/grandpa.tres")
## What a car gets in place of a fitted helmet, so it's never a wheel short.
const PLAIN_WHEEL := "res://scenes/parts/wheels/wheel_standard.tscn"

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var ask_line: String = "Well? How'd it go?"
@export var won_line: String = "See, if other people cared less about safety, they could've won."
@export var lost_line: String = "I'm taking that helmet back."
## Floats up off Grandpa as he takes it. `{part}` becomes the helmet's name.
@export var taken_text: String = "-{part}"

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
## Where the helmet ends up as he takes it, relative to Grandpa: in his lap.
@export var lap_offset := Vector2(0.0, -90.0)
@export var yank_seconds: float = 0.45
## How long it sits in his lap before the scene moves on.
@export var lap_seconds: float = 1.2

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var won := String(Quests.notes.get(QUEST_ID, "")) == "won"
	var helmet := GrandpaHelmetCutscene.helmet_part()
	var has_helmet := Inventory.owns_part(helmet)
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	var worn: Node2D = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
		if has_helmet:
			worn = GrandpaHelmetCutscene.helmet_prop(Vector2(4.0, -222.0), 1.25)
			player.attach(worn)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)
	await Cutscenes.wait(0.3)
	await _grandpa(ask_line)

	if won:
		await _grandpa(won_line)
		if not Cutscenes.is_skipping():
			grandpa.sip(-8.0)
		await Cutscenes.wait(0.6)
		return

	if not Cutscenes.is_skipping():
		grandpa.twitch(0.5, -6.0)
	await _grandpa(lost_line)
	if not has_helmet:
		await Cutscenes.wait(0.4)
		return
	# Taken even on a skip, so the helmet's gone either way.
	_take_helmet_back(helmet)
	if not Cutscenes.is_skipping():
		Pickup.spawn_float_text(grandpa.get_parent(), grandpa.global_position + lap_offset + Vector2(0.0, -50.0),
				taken_text.replace("{part}", helmet.display_name))
	await _yank(worn)
	await Cutscenes.wait(0.4)

## Every copy of the helmet leaves the player: out of the spare parts, or off
## a car, which gets a plain wheel bolted on in its place.
static func _take_helmet_back(helmet: PartData) -> void:
	var refit := false
	while Inventory.owns_part(helmet):
		var home := Inventory.detach_part(helmet)
		if home == null:
			break
		if home.car != null:
			Inventory.give_part(home, _plain_wheel())
			refit = refit or home.car == Inventory.get_selected_car()
	if refit:
		var car := (Engine.get_main_loop() as SceneTree).get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
		if car != null:
			car.refresh_parts()

static func _plain_wheel() -> PartData:
	for wheel: PartData in PartDatabase.wheels:
		if wheel.scene_path == PLAIN_WHEEL:
			return wheel.duplicate()
	return PartDatabase.load_part_data(PLAIN_WHEEL)

## The helmet flies off the player's head into Grandpa's lap.
func _yank(worn: Node2D) -> void:
	if worn == null or Cutscenes.is_skipping():
		return
	worn.reparent(grandpa.get_parent())
	Cutscenes.sound(&"helmet_bwomp", -4.0)
	var tween := worn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(worn, "global_position", grandpa.global_position + lap_offset, yank_seconds)
	tween.parallel().tween_property(worn, "rotation", -0.6, yank_seconds)
	await Cutscenes.play_tween(tween)
	if not Cutscenes.is_skipping():
		grandpa.sip(-8.0)
	await Cutscenes.wait(lap_seconds)
	worn.queue_free()

func _grandpa(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
