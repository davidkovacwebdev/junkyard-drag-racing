extends Node
## Who the player is (autoload `PlayerProfile`): the name they typed and the
## character they built on the New Game character creation screen. Saved
## and restored by SaveSystem.
##
## Story text can drop the player's name in with a `{player}` token:
## CharacterDialog.say() and Cutscenes.subtitle() both run their lines
## through `fill()`, so writers never have to build the string by hand.

## What `display_name()` falls back to for a save from before the player
## could pick a name.
const FALLBACK_NAME := "Rookie"
const MAX_NAME_LENGTH := 16
const NAME_TOKEN := "{player}"

var player_name: String = ""
## Set by character creation. A save without one (older than character
## creation, or a world started straight from the editor) gets a plain
## stand-in the first time it's asked for, so cutscenes always have the
## player to show. The save keeps it from then on.
var character: CharacterData = null:
	get:
		if character == null:
			character = _stand_in()
		return character

func reset() -> void:
	player_name = ""
	character = null

## The first part (by name) for every slot character creation always fills;
## no hair or accessory, like the creation screen's starting look.
static func _stand_in() -> CharacterData:
	var stand_in := CharacterData.new()
	stand_in.display_name = FALLBACK_NAME
	var parts := CharacterDatabase.scan_player_parts()
	for slot in CharacterPartData.Slot.values():
		if slot == CharacterPartData.Slot.HAIR or slot == CharacterPartData.Slot.ACCESSORY:
			continue
		var choices: Array = parts.get(slot, [])
		if not choices.is_empty():
			stand_in.set_part(slot, choices[0].scene)
	return stand_in

func display_name() -> String:
	return player_name if not player_name.is_empty() else FALLBACK_NAME

## Replaces every `{player}` in `text` with the player's name.
func fill(text: String) -> String:
	return text.replace(NAME_TOKEN, display_name())

## Trims what the player typed down to something that fits on a sign.
static func clean_name(raw: String) -> String:
	return raw.strip_edges().left(MAX_NAME_LENGTH).strip_edges()
