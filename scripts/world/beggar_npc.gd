class_name BeggarNpc
extends StaticBody2D
## A beggar sitting against the graveyard's front fence, by the gate, with a
## tin cup in front of him. Drive up and press E to talk: he asks for a
## little something, and the player can drop `scrap_gift` scrap or
## `money_gift` dollars in his cup. Either way he leans in with a tip: at
## night there are strange noises in there, so keep quiet (the cemetery's
## haunt, CemeteryHaunt, wakes on the horn).
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

var actor: CutsceneActor

var _dialog: CharacterDialog
var _talker: Node2D = null

func _ready() -> void:
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
	if TreasureRumors.can_ask():
		options.append(TreasureRumors.option(_dialog, CHARACTER))
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

## Clink in the cup, and the tip.
func _thanks() -> void:
	Sfx.play_at(&"tin_cup_clink", global_position + CUP_AT, -4.0)
	_dialog.say(tip_line)
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
