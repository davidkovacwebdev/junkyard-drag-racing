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
## Null until character creation has run (or on a save older than it).
var character: CharacterData = null

func reset() -> void:
	player_name = ""
	character = null

func display_name() -> String:
	return player_name if not player_name.is_empty() else FALLBACK_NAME

## Replaces every `{player}` in `text` with the player's name.
func fill(text: String) -> String:
	return text.replace(NAME_TOKEN, display_name())

## Trims what the player typed down to something that fits on a sign.
static func clean_name(raw: String) -> String:
	return raw.strip_edges().left(MAX_NAME_LENGTH).strip_edges()
