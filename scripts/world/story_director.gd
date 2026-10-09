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
## Grandpa sits just left of the car, wrench side towards it.
const GRANDPA_SPOT := OPENING_CAR_SPOT + Vector2(-105.0, 15.0)
## His bacon smoker stands off to his left (it hides itself until he's
## built it; see BaconSmoker).
const SMOKER_SPOT := GRANDPA_SPOT + Vector2(-210.0, -10.0)

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
	# Saves from before character creation have no player character; they
	# skip the intro rather than meeting Grandpa mid-game.
	if PlayerProfile.character == null or Cutscenes.has_seen(GrandpaScrapsCutscene.ID):
		return
	# Let the car and camera settle into place first.
	await get_tree().process_frame
	await get_tree().process_frame
	Cutscenes.play_once(_make_opening())

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
