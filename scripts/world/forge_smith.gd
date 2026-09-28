class_name ForgeSmith
extends StaticBody2D
## The scrap forge's smith. Drive up and press E (or left-click) to open the
## forge counter (ForgeScreen), where loose parts get melted into new ones.
##
## Same duck-typed interaction as HorseFarmer: a non-empty `display_name` makes
## him a target, `get_interact_prompt()` words the tooltip and `interact()`
## opens the counter.

@export var display_name: String = "Smith"
@export var forge_price: int = 60
## Drive further than this and the counter closes itself.
@export var dialog_range: float = 300.0

var _actor: Node2D = null
var _screen: ForgeScreen

func _ready() -> void:
	_screen = ForgeScreen.new()
	_screen.forge_price = forge_price
	add_child(_screen)
	_screen.closed.connect(func() -> void: _actor = null)

func _process(_delta: float) -> void:
	if not _screen.is_open():
		return
	if not is_instance_valid(_actor) \
			or global_position.distance_to(_actor.global_position) > dialog_range:
		_screen.close()

func get_interact_prompt() -> String:
	return "%s: E or left-click to forge parts ($%d)" % [display_name, forge_price]

func interact(actor: Node = null) -> void:
	if _screen.is_open():
		return
	_actor = actor as Node2D
	_screen.open()
