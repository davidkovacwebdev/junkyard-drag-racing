class_name BatteryAskCutscene
extends DetectorAskCutscene
## "Scrap Juice", at the junkyard counter: the player asks the man behind it
## (Vern, or whoever has his job now) for a battery. He's got a better idea:
## today's load in the crane pen has a battery-powered toy car motor in it,
## and the digs are on him. Played by ScrapDealer from his dialog; finishing
## it finishes the quest, and "Fish It Out" follows.
##
## The words live in res://cutscenes/battery_ask.tres; edit them in the
## inspector.

const BATTERY_ID := &"battery_ask"

@export var batteries_line: String = "Got any batteries lying around? The shop's out."
@export var motor_line: String = "Batteries? Hmm... There's a toy car motor in today's load out back. Those run on one."
@export var fish_line: String = "Fish it out with the claw if you can. Digs are on the house."
@export var deal_line: String = "Deal. Thanks!"

func _init() -> void:
	id = BATTERY_ID

func play() -> void:
	if not await stage():
		return
	await i_say(greeting())
	await i_say(batteries_line)
	await npc_says(motor_line)
	await npc_says(fish_line)
	await i_say(deal_line)
	await Cutscenes.wait(0.3)
	await Cutscenes.fade_out(0.5)
	unstage()
