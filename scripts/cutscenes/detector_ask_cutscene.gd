class_name DetectorAskCutscene
extends CoinsCutscene
## "Metal Head", at the junkyard counter: the player hops out and asks the man
## behind it (Vern, or whichever crane worker has his job now) where they
## could get a metal detector. He reckons Eugen had one, in his tool shed.
## Played by ScrapDealer from his dialog; finishing it finishes the quest,
## and "Grandpa's Shed" follows.
##
## The words live in res://cutscenes/detector_ask.tres; edit them in the
## inspector. `{name}` in `hey_line` becomes the man's name.

const ID := &"detector_ask"
## Only Vern gets greeted by name; the player doesn't know the new guys.
const VERN := "Vern"
const NAME_TOKEN := "{name}"

@export var hey_line: String = "Hey {name}."
@export var hey_stranger_line: String = "Hey."
@export var ask_line: String = "I guess I'll need a metal detector or something.. Any idea where I could get it?"
@export var shed_line: String = "I think Eugen had one, no? Have you checked his tool shed?"
@export var thanks_line: String = "I'll have a look, thanks."

func _init() -> void:
	id = ID

## "Hey Vern.", or just "Hey." to a crane worker the player doesn't know.
func greeting() -> String:
	return hey_line.replace(NAME_TOKEN, npc_name) if npc_name == VERN else hey_stranger_line

func play() -> void:
	if not await stage():
		return
	await i_say(greeting())
	await i_say(ask_line)
	await npc_says(shed_line)
	await i_say(thanks_line)
	await Cutscenes.wait(0.3)
	await Cutscenes.fade_out(0.5)
	unstage()
