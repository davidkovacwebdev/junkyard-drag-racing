class_name TreasureRumors
extends RefCounted
## "Ask Around" (after "Dig Deeper"): Chad has sent the player to snoop around
## town about the Junkyard Treasure. While it's on, everyone with a dialog
## (the junkyard counter, the shop, the horse farmer) gets an extra option to
## ask about it. For now nobody knows anything.

const QUEST := &"treasure_rumors"
const ASK_LINE := "Heard any rumors of the junkyard treasure lately?"
const ANSWER_LINE := "I don't know."

## Whether the player is asking around right now.
static func can_ask() -> bool:
	return Quests.has_quest(QUEST)

## What `who` says when asked. Everyone shrugs, for now.
static func answer(_who: CharacterData) -> String:
	return ANSWER_LINE

## The dialog option, for a CharacterDialog: `dialog` says the answer.
static func option(dialog: CharacterDialog, who: CharacterData) -> CharacterDialog.Option:
	return CharacterDialog.Option.new(ASK_LINE, func() -> void: dialog.say(answer(who)))
