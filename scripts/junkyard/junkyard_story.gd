class_name JunkyardStory
extends Node
## Lives in junkyard.tscn. While "What Happened?" is on, driving in plays
## the scene where the man at the counter tells the player how Grandpa died
## (JunkyardFlashbackCutscene), finishes the quest, and hands over
## Grandpa's note. With the trunk full, the note drops by the car as an orb
## instead, and drops again on every visit until the player has it.
##
## While the crane is down (CraneWreck) it lies in the yard where it fell,
## creaking now and then, and the man at the counter stands clear of it.
##
## The quest finishes when the scene does, not when the note is owned: a
## note already in the trunk (say, from testing with the F5 board) mustn't
## finish the quest before the player has even been here.

const QUEST_ID := &"junkyard_truth"
const SCENE_PATH := "res://cutscenes/junkyard_flashback.tres"
const NOTE := preload("res://items/grandpas_note.tres")
## Where the man at the counter stands while the crane lies across his spot.
const DEALER_CLEAR_OF_WRECK := Vector2(560.0, 580.0)

func _enter_tree() -> void:
	# Before anything else is ready, so nothing sees the crane standing.
	get_parent().ready.connect(_show_wreck, CONNECT_ONE_SHOT)

func _show_wreck() -> void:
	var crane := get_parent().get_node_or_null(^"Yard/Crane") as JunkyardCrane
	if not CraneWreck.lay_down(crane):
		return
	var dealer := get_parent().get_node_or_null(^"Yard/Dealer") as Node2D
	if dealer != null:
		dealer.position = DEALER_CLEAR_OF_WRECK
	var creak := AmbientCall.new()
	creak.sound_name = &"cable_creak"
	creak.interval_range = Vector2(7.0, 15.0)
	creak.volume_db = -10.0
	creak.max_distance = 1800.0
	crane.add_child(creak)
	creak.position = Vector2(0.0, -350.0)

func _ready() -> void:
	if Quests.has_quest(QUEST_ID):
		_tell.call_deferred()
	elif Quests.is_complete(QUEST_ID) and not Inventory.has_item(NOTE.id):
		_hand_over_note.call_deferred()

func _tell() -> void:
	# Let the car and its camera settle into place first.
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as JunkyardFlashbackCutscene
	if scene != null:
		scene.yard = get_parent() as Node2D
		Music.hush(true, 1.0)
		await Cutscenes.play(scene)
		Music.hush(false)
	Quests.complete(QUEST_ID)
	_hand_over_note()
	SaveSystem.save_game()

func _hand_over_note() -> void:
	if Inventory.has_item(NOTE.id):
		return
	if Inventory.give_item(NOTE):
		Sfx.play(&"paper_unfold", -4.0, 0.0)
		return
	var car := get_parent().get_node_or_null(^"Yard/PlayerCar") as Node2D
	if car == null:
		return
	var orb := ItemPickup.new()
	orb.configure(NOTE)
	car.get_parent().add_child(orb)
	orb.launch(car.global_position + Vector2(160.0, -40.0), car.global_position + Vector2(170.0, 30.0), 60.0, 0.5)
