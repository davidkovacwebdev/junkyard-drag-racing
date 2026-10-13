class_name StoryDirector
extends Node
## Puts the story's characters into the open world and starts story
## cutscenes when their moment comes. Lives in main.tscn, so it runs every
## time the map loads.
##
## For now that's the opening: Grandpa is parked beside the starter car, and
## on a fresh game (one that went through character creation) his opening
## scene plays once and hands out the first quest. His wrench scene
## (cutscenes/grandpa_intro.tres) is kept for a later quest.

## Where a new game's car starts: in front of Grandpa's garage door, clear of
## the dumpsters on either side. Character creation parks the car here.
const OPENING_CAR_SPOT := Vector2(310.0, -105.0)
## Grandpa sits by the garage's left corner, far enough from the door that
## pulling up to it doesn't reach him too.
const GRANDPA_SPOT := OPENING_CAR_SPOT + Vector2(-260.0, -15.0)
## His bacon smoker stands down the yard off his left, by the road and clear
## of the bay spots (it hides itself until he's built it; see BaconSmoker).
const SMOKER_SPOT := OPENING_CAR_SPOT + Vector2(-450.0, 120.0)
## Over the west bridge, on the big island: Chad's house, and Chad out front
## of it, just north of where the bridge lands (-16800, 2000), out of the
## car's way.
const CHAD_HOUSE := preload("res://buildings/house_06.tres")
const CHAD_HOUSE_SPOT := Vector2(-17700.0, 1640.0)
const CHAD_SPOT := Vector2(-17380.0, 1760.0)
const BUILDING_SCENE := preload("res://scenes/world/composed_building.tscn")
## The beggar sits outside the graveyard's front fence, right of its gate.
const BEGGAR_FROM_GATE := Vector2(170.0, 46.0)

const GROUP := &"story_director"
## The opening's lines and staging; edit them in the inspector on the .tres.
const OPENING_PATH := "res://cutscenes/grandpa_scraps.tres"

@export var sortables_path: NodePath = ^"../Sortables"

var _grandpa: GrandpaNpc

func _ready() -> void:
	var sortables := get_node(sortables_path)
	add_to_group(GROUP)
	var grandpa := GrandpaNpc.new()
	grandpa.position = GRANDPA_SPOT
	sortables.add_child.call_deferred(grandpa)
	_grandpa = grandpa
	var smoker := BaconSmoker.new()
	smoker.position = SMOKER_SPOT
	sortables.add_child.call_deferred(smoker)
	_place_chad(sortables)
	_place_beggar.call_deferred(sortables)
	var digger := NightDiggerSpawner.new()
	digger.sortables = sortables
	add_child(digger)
	add_child(TreasureStory.new())
	add_child(DinnerStory.new())
	# Saves from before character creation have no player character; they
	# skip the intro rather than meeting Grandpa mid-game.
	if PlayerProfile.character == null or Cutscenes.has_seen(GrandpaScrapsCutscene.ID):
		return
	# Let the car and camera settle into place first.
	await get_tree().process_frame
	await get_tree().process_frame
	Cutscenes.play_once(_make_opening())

## Chad's house on the island past the west bridge, and Chad. Added from here
## rather than placed in main.tscn.
func _place_chad(sortables: Node) -> void:
	var house := BUILDING_SCENE.instantiate() as ComposedBuilding
	house.name = "ChadsHouse"
	house.building_data = CHAD_HOUSE
	house.position = CHAD_HOUSE_SPOT
	sortables.add_child.call_deferred(house)
	var chad := ChadNpc.new()
	chad.name = "Chad"
	chad.position = CHAD_SPOT
	sortables.add_child.call_deferred(chad)

## The beggar by the graveyard gate (BeggarNpc), once the gate is in the tree.
func _place_beggar(sortables: Node) -> void:
	var gate := get_tree().get_first_node_in_group(GraveyardGate.GROUP) as Node2D
	if gate == null:
		return
	var beggar := BeggarNpc.new()
	beggar.name = "Beggar"
	sortables.add_child(beggar)
	beggar.global_position = gate.global_position + BEGGAR_FROM_GATE

## Grandpa, parked by the garage (or the spot he used to sit in).
func grandpa() -> GrandpaNpc:
	return _grandpa

## Plays the opening again even if it was already seen (dev menu, F3), so its
## lines can be tuned without starting a new game each time.
func replay_opening() -> void:
	Cutscenes.play(_make_opening())

func _make_opening() -> GrandpaScrapsCutscene:
	# Loaded fresh (not preloaded) so edits saved in the editor show up on replay.
	var opening := ResourceLoader.load(OPENING_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as GrandpaScrapsCutscene
	opening.grandpa = _grandpa
	return opening
