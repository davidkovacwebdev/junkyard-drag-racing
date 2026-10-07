class_name HorseFarmer
extends StaticBody2D
## The farm's horse seller. Drive up and press E (or left-click) to talk; he
## sells a horse, which lands in the spare parts like any other engine and is
## bolted on in the garage.
##
## Same duck-typed interaction as ScrapDealer: a non-empty `display_name`
## makes him a target, `get_interact_prompt()` words the tooltip and
## `interact()` opens the dialog.
##
## He won't sell until the player has `opens_with_quest` (Grandpa's "Giddy
## Up"), or has finished it.

@export var display_name: String = "Farmer"
@export var horse_price: int = 300
## The engine part he sells, looked up in PartDatabase by id.
@export var horse_part_id: StringName = &"engine_horse"
## Drive further than this and the dialog closes itself.
@export var dialog_range: float = 300.0
## Empty: sells from the start. Otherwise no horse until the player has
## this quest, or has finished it.
@export var opens_with_quest: StringName = &""

@export_group("Lines")
@export var greet_line: String = "Howdy! Fine horse here. Pulls a car better'n any motor, and she runs on hay."
@export var sold_line: String = "She's yours. Hitch her up in the garage, she'll pull whatever you bolt her to."
@export var broke_line: String = "That's $%d, friend. Come back when your pockets jingle."
@export var closed_line: String = "Horses ain't for sale right now, partner. Got nobody needs one bad enough."

const POPUP_RISE := 54.0
const POPUP_LIFETIME := 1.4
const _OPTION_KEYS := [KEY_1, KEY_2]

var _popup_home: Vector2 = Vector2.ZERO
var _actor: Node2D = null

@onready var _dialog: CanvasLayer = $Dialog
@onready var _line: Label = $Dialog/Board/Layout/LineLabel
@onready var _stats: Label = $Dialog/Board/Layout/StatsLabel
@onready var _buy_button: ScrapButton = $Dialog/Board/Layout/Buttons/BuyButton
@onready var _leave_button: ScrapButton = $Dialog/Board/Layout/Buttons/LeaveButton
@onready var _popup: Label = $Popup

func _ready() -> void:
	_popup_home = _popup.position
	_buy_button.pressed.connect(buy_horse)
	_leave_button.pressed.connect(_close)
	for button in [_buy_button, _leave_button]:
		button.focus_mode = Control.FOCUS_NONE
	_close()

func _process(_delta: float) -> void:
	if not _is_open():
		return
	if not is_instance_valid(_actor) \
			or global_position.distance_to(_actor.global_position) > dialog_range:
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var options := [_buy_button, _leave_button]
	var index := _OPTION_KEYS.find(event.keycode)
	if index == -1:
		return
	get_viewport().set_input_as_handled()
	options[index].pressed.emit()

func get_interact_prompt() -> String:
	return "%s: E or left-click to talk ($%d)" % [display_name, Inventory.money]

func interact(actor: Node = null) -> void:
	if actor != null:
		_actor = actor as Node2D
	var farmer := ($Character as CharacterRig).character_data
	if not _is_selling():
		_line.text = closed_line
	else:
		_line.text = PlayerProfile.fill(farmer.idle_line(greet_line) if farmer != null else greet_line)
	_refresh()
	_dialog.visible = true

## Trade `horse_price` for a horse in the spare parts. Returns whether it sold.
func buy_horse() -> bool:
	var horse := _horse_part()
	if horse == null:
		return false
	if not _is_selling():
		Sfx.play(&"denied", -6.0, 0.0)
		_say(closed_line)
		return false
	if not Inventory.spend_money(horse_price):
		Sfx.play(&"denied", -6.0, 0.0)
		_say(broke_line % horse_price)
		_show_popup("Not enough cash")
		return false
	Inventory.add_part(horse)
	SaveSystem.save_game()
	Sfx.play(&"cash_register", -4.0, 0.0)
	Sfx.play(&"horse_neigh", -6.0)
	_say(sold_line)
	_show_popup("-$%d" % horse_price)
	return true

func _is_selling() -> bool:
	return opens_with_quest.is_empty() or Quests.has_quest(opens_with_quest) \
			or Quests.is_complete(opens_with_quest)

func _horse_part() -> PartData:
	for engine in PartDatabase.engines:
		if engine.id == horse_part_id:
			return engine
	push_error("HorseFarmer: no engine part with id '%s'" % horse_part_id)
	return null

func _say(text: String) -> void:
	_line.text = text
	_refresh()

func _refresh() -> void:
	_buy_button.text = "1. Buy a Horse ($%d)" % horse_price
	_buy_button.disabled = not _is_selling()
	_stats.text = "You have $%d" % Inventory.money

func _close() -> void:
	_actor = null
	_dialog.visible = false

func _is_open() -> bool:
	return is_instance_valid(_dialog) and _dialog.visible

func _show_popup(text: String) -> void:
	_popup.text = text
	_popup.visible = true
	_popup.position = _popup_home
	_popup.modulate.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_popup, "position:y", _popup_home.y - POPUP_RISE, POPUP_LIFETIME)
	tween.parallel().tween_property(
			_popup, "modulate:a", 0.0, POPUP_LIFETIME * 0.6).set_delay(POPUP_LIFETIME * 0.35)
	tween.tween_callback(func() -> void: _popup.visible = false)
