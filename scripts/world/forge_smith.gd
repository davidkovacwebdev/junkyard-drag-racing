class_name ForgeSmith
extends StaticBody2D
## The scrap forge's smith. Drive up and press E (or left-click) to open the
## forge counter (ForgeScreen), where loose parts get melted into new ones.
##
## Same duck-typed interaction as HorseFarmer: a non-empty `display_name` makes
## him a target, `get_interact_prompt()` words the tooltip and `interact()`
## opens the counter.
##
## At night while the player is asking around about the treasure (until he's
## caught) he's out in his pickup (NightDiggerSpawner.digger_out()): he isn't
## at the forge, can't be talked to, and is back in the morning.

const GROUP := &"forge_smith"
## What he says about the treasure once he's confessed (TreasureStory).
const CAUGHT_LINE := "I told you everything I know. Now leave me be."

@export var display_name: String = "Gus"
@export var forge_price: int = 60
## Drive further than this and the counter closes itself.
@export var dialog_range: float = 300.0

var _actor: Node2D = null
var _screen: ForgeScreen
## His name while he's in; `display_name` empties while he's out so the car
## doesn't offer to talk to nobody.
var _name: String
var _away := false

func _ready() -> void:
	add_to_group(GROUP)
	_name = display_name
	_screen = ForgeScreen.new()
	_screen.forge_price = forge_price
	var rig := get_node_or_null("Character") as CharacterRig
	if rig != null:
		_screen.character = rig.character_data
	add_child(_screen)
	_screen.closed.connect(func() -> void: _actor = null)
	_screen.asked_about_treasure.connect(_ask_about_treasure)

func _process(_delta: float) -> void:
	var away := NightDiggerSpawner.digger_out() and not Cutscenes.is_active()
	if away != _away:
		_set_away(away)
	if not _screen.is_open():
		return
	if not is_instance_valid(_actor) \
			or global_position.distance_to(_actor.global_position) > dialog_range:
		_screen.close()

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
		_screen.close()

## Whether he's out in his pickup rather than at the forge.
func is_away() -> bool:
	return _away

func get_interact_prompt() -> String:
	return "%s: E or left-click to forge parts ($%d)" % [display_name, forge_price]

func interact(actor: Node = null) -> void:
	if _screen.is_open() or _away:
		return
	_actor = actor as Node2D
	_screen.open()

## "Ask Around": the first time he shows off his coins (SmithCoinsCutscene)
## and throws the player out; after the beggar's tip, he's accused and does
## it again (SmithConfrontCutscene).
func _ask_about_treasure() -> void:
	if TreasureStory.gus_caught():
		_screen.say(CAUGHT_LINE)
		return
	if TreasureRumors.has_scene(TreasureRumors.SMITH):
		_screen.close()
		TreasureRumors.play_scene(TreasureRumors.SMITH, get_node_or_null("Character") as CharacterRig)
		return
	_screen.say(TreasureRumors.answer(TreasureRumors.SMITH))
