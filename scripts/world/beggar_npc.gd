class_name BeggarNpc
extends StaticBody2D
## A beggar sitting against the graveyard's front fence, by the gate, with a
## tin cup in front of him. Drive up and press E to talk: he asks for a
## little something, and the player can drop `scrap_gift` scrap or
## `money_gift` dollars in his cup. The first time, he leans in with a tip:
## at night there are strange noises in there, so keep quiet (the cemetery's
## haunt, CemeteryHaunt, wakes on the horn). After that he just thanks the
## player, and once in a while does the "six seven" hands (SixSevenHands).
##
## During "Ask Around" he knows something about the Junkyard Treasure, for a
## six-pack and some scrap ("Wet His Whistle"); paid, he tells of a man in a
## welding mask digging at night with a kid ("Graveyard Shift" follows).
##
## Placed by StoryDirector next to the GraveyardGate, from code rather than
## main.tscn.

const CHARACTER := preload("res://characters/beggar.tres")
const DIALOG_SCENE := preload("res://scenes/ui/character_dialog.tscn")
const ACTOR_SCALE := 0.55
const BODY_SIZE := Vector2(44.0, 14.0)
## Hunched over his cup.
const STOOP := 0.12
## His tin cup, on the ground in front of him: the cup and its rim.
const CUP_AT := Vector2(-34.0, 8.0)
const CUP := Color(0.6, 0.6, 0.58, 1)
const CUP_SHADE := Color(0.47, 0.47, 0.45, 1)

@export var display_name: String = "Beggar"
@export var dialog_range: float = 300.0
@export var scrap_gift: int = 5
@export var money_gift: int = 5
@export_multiline var tip_line: String = "Hey, lemme tell you something. At night I hear some straaange noises out here. If you ever come here at night make sure to be quiet. So quiet."
@export var broke_line: String = "Ain't got it either, huh? I know the feelin'."
## After the first gift (which gets `tip_line`), each one gets one of these.
@export var thanks_lines: PackedStringArray = [
	"Thankss man",
	"Oh, I'll be able to drink more",
	"Thanks, you helped me decide to never get a job",
	"Free money ezzz",
]
## The rare one, with the hands going (SixSevenHands).
@export var six_seven_line: String = "Six seveeen"
@export_range(0.0, 1.0) var six_seven_chance: float = 1.0 / 12.0
@export_group("Treasure")
@export var price_line: String = "Oh, I know some info. But I'll need a six-pack and some scrap."
@export_multiline var info_line: String = "During the night, I've noticed a guy wearing a welding mask drivin' around out here, on the roads just outside the graveyard, in a little brown pickup. Never comes inside. He brings a kid with him, and they dig somethin' up, or I dunno."
@export var hand_over_text: String = "Here's your six-pack and scrap"

const INFO_QUEST := preload("res://quests/beggar_info.tres")

var actor: CutsceneActor
## For the minimap's quest-giver heads (Minimap.GIVER_GROUP).
var character_data: CharacterData = CHARACTER

var _dialog: CharacterDialog
var _last_thanks := -1
## WorldState claim: he's told the player about the night noises already.
const TIP_GIVEN := "beggar_tip"
var _talker: Node2D = null

func _ready() -> void:
	add_to_group(Minimap.GIVER_GROUP)
	actor = CutsceneActor.new()
	actor.setup(CHARACTER, ACTOR_SCALE)
	actor.rotation = STOOP
	add_child(actor)
	actor.face(false)
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -BODY_SIZE.y * 0.5)
	add_child(collision)
	_dialog = DIALOG_SCENE.instantiate()
	add_child(_dialog)

func _process(_delta: float) -> void:
	if _dialog.is_open() and (not is_instance_valid(_talker)
			or global_position.distance_to(_talker.global_position) > dialog_range):
		_dialog.close()

func get_interact_prompt() -> String:
	return "%s: Press E to talk" % display_name

## Called by PlayerCar on E or a click.
func interact(talker: Node = null) -> void:
	if _dialog.is_open() or Cutscenes.is_active():
		return
	_talker = talker as Node2D
	_dialog.open(display_name, CHARACTER)
	_dialog.say(PlayerProfile.fill(CHARACTER.idle_line("Spare a little somethin'?")))
	_refresh()

func _refresh() -> void:
	var options := [
		CharacterDialog.Option.new("Give him %d scrap" % scrap_gift, _give_scrap, Inventory.scrap < scrap_gift),
		CharacterDialog.Option.new("Give him $%d" % money_gift, _give_money, Inventory.money < money_gift),
	]
	if Quests.has_quest(INFO_QUEST.id):
		options.append(_hand_over_option())
	elif TreasureRumors.can_ask() or Quests.is_complete(INFO_QUEST.id):
		options.append(CharacterDialog.Option.new(TreasureRumors.ASK_LINE, _ask_about_treasure))
	options.append(CharacterDialog.Option.new("Walk away", _dialog.close))
	_dialog.set_options(options, false)

func _give_scrap() -> void:
	if Inventory.scrap < scrap_gift:
		_turned_down()
		return
	Inventory.scrap -= scrap_gift
	_thanks()

func _give_money() -> void:
	if not Inventory.spend_money(money_gift):
		_turned_down()
		return
	_thanks()

## Clink in the cup, and the tip the first time; just thanks after that.
func _thanks() -> void:
	Sfx.play_at(&"tin_cup_clink", global_position + CUP_AT, -4.0)
	if not WorldState.is_claimed(TIP_GIVEN):
		WorldState.mark_claimed(TIP_GIVEN)
		_dialog.say(tip_line)
	elif randf() < six_seven_chance:
		_dialog.say(six_seven_line)
		SixSevenHands.play(_dialog.portrait_rig())
	else:
		var pick := randi() % thanks_lines.size()
		if pick == _last_thanks:
			pick = (pick + 1) % thanks_lines.size()
		_last_thanks = pick
		_dialog.say(thanks_lines[pick])
	_refresh()
	SaveSystem.save_game()

## Not for free: he names his price and it goes in the journal. Once he's
## been paid he just tells it again.
func _ask_about_treasure() -> void:
	if Quests.is_complete(INFO_QUEST.id):
		_dialog.say(info_line)
	elif Quests.has_quest(INFO_QUEST.id):
		_dialog.say(INFO_QUEST.reminder_line)
	else:
		_dialog.say(price_line)
		Quests.give(INFO_QUEST)
		SaveSystem.save_game()
	_refresh()

## "Here's your six-pack and scrap", greyed out with what's still missing
## until the player has both.
func _hand_over_option() -> CharacterDialog.Option:
	var missing: Array[String] = []
	if not Inventory.has_item(INFO_QUEST.item_goal.id):
		missing.append("a six-pack")
	if Inventory.scrap < INFO_QUEST.scrap_goal:
		missing.append("%d scrap, have %d" % [INFO_QUEST.scrap_goal, Inventory.scrap])
	if missing.is_empty():
		return CharacterDialog.Option.new("%s (%d scrap)" % [hand_over_text, INFO_QUEST.scrap_goal], _hand_over)
	return CharacterDialog.Option.new("%s (need %s)" % [hand_over_text, ", ".join(missing)], _hand_over, true)

## The six-pack and scrap go in the cup, a can cracks, and he talks.
func _hand_over() -> void:
	if not Quests.is_ready(INFO_QUEST.id):
		Quests.goal_met(INFO_QUEST.id)
	if Quests.turn_in(INFO_QUEST.id) < 0:
		_turned_down()
		_refresh()
		return
	Sfx.play_at(&"tin_cup_clink", global_position + CUP_AT, -4.0)
	Sfx.play(&"beer_crack", -4.0, 0.05)
	_dialog.say(info_line)
	_refresh()
	SaveSystem.save_game()

func _turned_down() -> void:
	Sfx.play(&"denied", -6.0, 0.0)
	_dialog.say(broke_line)

## The tin cup in front of him.
func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([CUP_AT + Vector2(-9.0, -18.0), CUP_AT + Vector2(9.0, -18.0),
			CUP_AT + Vector2(7.0, 0.0), CUP_AT + Vector2(-7.0, 0.0)]), CUP)
	draw_rect(Rect2(CUP_AT + Vector2(2.0, -18.0), Vector2(5.0, 18.0)), CUP_SHADE)
