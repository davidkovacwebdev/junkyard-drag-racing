class_name ForgeSmith
extends StaticBody2D
## The scrap forge's smith. Drive up and press E (or left-click) to open the
## forge counter (ForgeScreen), where loose parts get melted into new ones.
##
## Same duck-typed interaction as HorseFarmer: a non-empty `display_name` makes
## him a target, `get_interact_prompt()` words the tooltip and `interact()`
## opens the counter.
##
## Until "Hammer Time" is done his anvil is missing, so instead of the counter
## he opens a CharacterDialog: the first talk hands out the quest, and once the
## car he's talking to rolls in on an anvil wheel he takes it back
## (ForgeAnvilCutscene).
##
## Keeps business hours (DayNightCycle.is_business_hours()): outside them
## he's still standing there but the forge is shut and he won't talk.
##
## At night while the player is asking around about the treasure (until he's
## caught) he's out in his pickup (NightDiggerSpawner.digger_out()): he isn't
## at the forge, can't be talked to, and is back in the morning.

const GROUP := &"forge_smith"
## What he says about the treasure once he's confessed (TreasureStory).
const CAUGHT_LINE := "I told you everything I know. Now leave me be."

const DIALOG_SCENE := preload("res://scenes/ui/character_dialog.tscn")
const ANVIL_QUEST := preload("res://quests/forge_anvil.tres")
const ANVIL_SCENE := preload("res://cutscenes/forge_anvil.tres")

@export var display_name: String = "Gus"
@export var forge_price: int = 60
## Drive further than this and the counter closes itself.
@export var dialog_range: float = 300.0
## The stump his anvil sits on (bare until "Hammer Time" is done).
@export var stump_path: NodePath = ^"../Anvil"

@export_group("No Anvil")
@export var no_anvil_line: String = "Forge is cold, pal. Some joker walked off with my anvil. Can't hammer nothin' without an anvil."
@export var hand_over_text: String = "Here's an anvil"
@export var hand_over_missing_text: String = "(bolt one on your car first)"

## For the minimap's quest-giver heads (Minimap.GIVER_GROUP).
var character_data: CharacterData

var _actor: Node2D = null
var _screen: ForgeScreen
var _dialog: CharacterDialog
var _stump: ForgeProp
## His name while he's in; `display_name` empties while he's out so the car
## doesn't offer to talk to nobody.
var _name: String
var _away := false

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Minimap.GIVER_GROUP)
	_name = display_name
	_stump = get_node_or_null(stump_path) as ForgeProp
	_screen = ForgeScreen.new()
	_screen.forge_price = forge_price
	var rig := get_node_or_null("Character") as CharacterRig
	if rig != null:
		character_data = rig.character_data
		_screen.character = character_data
	add_child(_screen)
	_screen.closed.connect(func() -> void: _actor = null)
	_screen.asked_about_treasure.connect(_ask_about_treasure)
	_dialog = DIALOG_SCENE.instantiate()
	add_child(_dialog)
	_dialog.closed.connect(func() -> void: _actor = null)

func _process(_delta: float) -> void:
	var away := NightDiggerSpawner.digger_out() and not Cutscenes.is_active()
	if away != _away:
		_set_away(away)
	if _stump != null and not Cutscenes.is_active():
		_stump.anvil_on_stump = has_anvil()
	if not _screen.is_open() and not _dialog.is_open():
		return
	if not is_instance_valid(_actor) \
			or global_position.distance_to(_actor.global_position) > dialog_range:
		_close()

func _set_away(away: bool) -> void:
	_away = away
	display_name = "" if away else _name
	var rig := get_node_or_null("Character") as Node2D
	if rig != null:
		rig.visible = not away
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", away)
	if away:
		_close()

## Whether he has his anvil back ("Hammer Time" is done) and can forge.
static func has_anvil() -> bool:
	return Quests.is_complete(ANVIL_QUEST.id)

## Whether he's out in his pickup rather than at the forge.
func is_away() -> bool:
	return _away

func is_closed() -> bool:
	return not DayNightCycle.is_business_hours()

func get_interact_prompt() -> String:
	if not has_anvil():
		return "%s: Press E to talk" % display_name
	return "%s: E or left-click to forge parts ($%d)" % [display_name, forge_price]

func interact(actor: Node = null) -> void:
	if _screen.is_open() or _dialog.is_open() or _away or Cutscenes.is_active():
		return
	_actor = actor as Node2D
	if has_anvil():
		_screen.open()
		return
	_dialog.open(display_name, character_data)
	if Quests.has_quest(ANVIL_QUEST.id):
		_dialog.say(ANVIL_QUEST.reminder_line)
	else:
		_dialog.say(no_anvil_line)
		Quests.give(ANVIL_QUEST)
		SaveSystem.save_game()
	_refresh_dialog()

func _refresh_dialog() -> void:
	var on_car := ForgeAnvilCutscene.driving_on_anvil()
	var options := [CharacterDialog.Option.new(
			hand_over_text if on_car else "%s %s" % [hand_over_text, hand_over_missing_text],
			_hand_over_anvil, not on_car)]
	if TreasureRumors.can_ask():
		options.append(CharacterDialog.Option.new(TreasureRumors.ASK_LINE, _ask_about_treasure))
	options.append(CharacterDialog.Option.new("Walk away", _dialog.close))
	_dialog.set_options(options, false)

func _hand_over_anvil() -> void:
	if not ForgeAnvilCutscene.driving_on_anvil():
		return
	_dialog.close()
	var scene: ForgeAnvilCutscene = ANVIL_SCENE.duplicate()
	scene.npc_rig = get_node_or_null("Character") as CharacterRig
	scene.stump = _stump
	await Cutscenes.play(scene)
	Quests.complete(ANVIL_QUEST.id)
	SaveSystem.save_game()

func _close() -> void:
	_screen.close()
	_dialog.close()

## "Ask Around": the first time he shows off his coins (SmithCoinsCutscene)
## and throws the player out; after the beggar's tip, he's accused and does
## it again (SmithConfrontCutscene).
func _ask_about_treasure() -> void:
	if TreasureStory.gus_caught():
		_screen.say(CAUGHT_LINE)
		return
	if TreasureRumors.has_scene(TreasureRumors.SMITH):
		_close()
		TreasureRumors.play_scene(TreasureRumors.SMITH, get_node_or_null("Character") as CharacterRig)
		return
	var answer := TreasureRumors.answer(TreasureRumors.SMITH)
	if _dialog.is_open():
		_dialog.say(answer)
	else:
		_screen.say(answer)
