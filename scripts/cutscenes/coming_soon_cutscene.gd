class_name ComingSoonCutscene
extends Cutscene
## The end of the story so far: the screen fades to black and a big card says
## there's more to come. Played by TreasureStory once "The Dig Site" is done.
##
## The words live in res://cutscenes/coming_soon.tres.

const ID := &"coming_soon"

@export_multiline var card_text: String = "That's all for now,\nexpect more quests soon"
@export var seconds: float = 5.0

func _init() -> void:
	id = ID

func play() -> void:
	await Cutscenes.fade_out(0.6)
	Cutscenes.sound(&"quest_complete", -2.0)
	await Cutscenes.title_card(card_text, seconds)
