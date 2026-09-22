class_name ScrapDealer
extends StaticBody2D
## The junkyard's buyer: the punker from the character creator, standing beside
## the crane. Drive up to him and press E (or left-click) for the dialog,
## which is where the two things worth doing at the yard live:
##
##   1. sell the whole scrap pile for cash,
##   2. point the player at the crane pen behind the yard, where they drive the
##      crane themselves and keep whatever the jaws come up with.
##
## The digging itself doesn't happen here: he's the man with the money, the pen
## is the machine. His crane button is a door to
## res://scenes/junkyard/crane_pen.tscn, and the pen's crane does the charging
## — which is why `crane_cost` below is only what his sign says, not what the
## machine takes.
##
## Duck-typed for PlayerCar the same way TrashProp is:
##   - a non-empty `display_name` makes him an interaction target at all,
##   - `get_interact_prompt()` supplies the wording, because talking to a
##     person isn't "entering" him, which is PlayerCar's default verb,
##   - `interact()` is what both E and a left-click end up calling.
## Being a StaticBody2D means two things: the car can't drive through him, and
## the click has an actual shape to hit — PlayerCar's click is a point query
## against the physics world, not a mouse-over test.
##
## He doesn't carry a copy of the punker's parts: the `Character` child is a
## CharacterRig pointed at res://characters/punker.tres, so editing that .tres
## in the Character Creator changes this guy too.
##
## The dialog lives in this scene as a CanvasLayer rather than in a scene of its
## own: it only ever belongs to him, and keeping it here means the whole dealer
## (art, collision, dialog) is one `instantiate()` for anyone building a second
## yard.

@export var display_name: String = "Scrap Dealer"
## Cash paid per unit of scrap. 1 keeps the loot numbers readable.
@export var money_per_scrap: int = 1

@export_group("Crane")
## What his sign says a dig costs. Advertising only — the pen's own crane
## (`CraneRig.grab_cost`) is what actually takes the money, so keep the two in
## step by hand if you reprice a dig.
@export var crane_cost: int = 100
## Where the crane button sends the player: the pen out back, crane and all.
@export_file("*.tscn") var pen_scene: String = "res://scenes/junkyard/crane_pen.tscn"
## Drive further than this and the dialog closes itself, so it can't be left
## hanging over the yard from an empty stall.
@export var dialog_range: float = 300.0

@export_group("Lines")
@export var empty_line: String = "Nothin' worth sellin', friend."
@export var sold_line: String = "That's %d scrap - here's $%d."
@export var greet_line: String = "Buyin' scrap. Or take the crane out back and dig for somethin' better yourself."

const POPUP_RISE := 54.0
const POPUP_LIFETIME := 1.4

## Where the Popup label rests, captured from the scene in _ready().
var _popup_home: Vector2 = Vector2.ZERO
## The car that opened the dialog, so it can be closed when that car drives off.
var _actor: Node2D = null

@onready var _dialog: CanvasLayer = $Dialog
@onready var _line: Label = $Dialog/Panel/Layout/LineLabel
@onready var _stats: Label = $Dialog/Panel/Layout/StatsLabel
@onready var _sell_button: Button = $Dialog/Panel/Layout/SellButton
@onready var _crane_button: Button = $Dialog/Panel/Layout/CraneButton
@onready var _leave_button: Button = $Dialog/Panel/Layout/LeaveButton

## Number-key shortcuts for the dialog's buttons, in the same top-to-bottom
## order the numbers printed on them read (see _refresh()/the .tscn's
## static "3. Walk away") — pressing 1/2/3 is the same as clicking the
## button in that slot.
const _OPTION_KEYS := [KEY_1, KEY_2, KEY_3]

func _ready() -> void:
	var popup := get_node_or_null("Popup") as Label
	if popup != null:
		_popup_home = popup.position
	_close()

func _process(_delta: float) -> void:
	if not _is_open():
		return
	# Talk to the car in front of you, not to the empty stall it just left.
	if not is_instance_valid(_actor) \
			or global_position.distance_to(_actor.global_position) > dialog_range:
		_close()

## Lets the player pick a dialog option by number instead of clicking.
## Only live while the dialog is actually open, and only consumes the
## keys it recognizes, so it can't eat input meant for anything else.
func _unhandled_input(event: InputEvent) -> void:
	if not _is_open() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var options := [_sell_button, _crane_button, _leave_button]
	var index := _OPTION_KEYS.find(event.keycode)
	if index == -1 or index >= options.size():
		return
	var button: Button = options[index]
	if button.disabled:
		return
	# Marked handled BEFORE emitting: the crane option changes scenes from
	# inside its own pressed handler, which can free this node (and with it
	# the viewport reference) before emit() even returns — calling
	# get_viewport() afterward hit exactly that null.
	get_viewport().set_input_as_handled()
	button.pressed.emit()

## Wording for PlayerCar's proximity tooltip. Shows the haul and the wallet, so
## the prompt doubles as the "what have I got" readout at the yard.
func get_interact_prompt() -> String:
	return "%s: E or left-click to talk (%d scrap, $%d)" % [
		display_name, Inventory.scrap, Inventory.money]

## Called by PlayerCar on E or a left-click. Opens the dialog rather than
## trading straight away, because there are two things to do here now.
func interact(actor: Node = null) -> void:
	if actor != null:
		_actor = actor as Node2D
	_open()

func _on_sell_pressed() -> void:
	sell()
	_refresh()

## Send the player to the crane. Nothing is charged here — the pen's crane bills
## per dig, and the money is no good to the player standing in this yard
## anyway.
func _on_crane_pressed() -> void:
	if pen_scene.is_empty():
		return
	_close()
	SaveSystem.save_game()
	get_tree().change_scene_to_file(pen_scene)

func _on_leave_pressed() -> void:
	_close()

## Show the dialog on the car we're talking to, primed with his opening line.
func _open() -> void:
	_set_line(greet_line)
	_refresh()
	_dialog.visible = true

## Hide it and forget the car.
func _close() -> void:
	_actor = null
	if is_instance_valid(_dialog):
		_dialog.visible = false

func _is_open() -> bool:
	return is_instance_valid(_dialog) and _dialog.visible

## Reflect the world in the panel: what he'd pay for the scrap, what a grab
## costs, and what the player is carrying. Numbers stay pinned to the front
## of each label (matching LeaveButton's static "3. Walk away") so the
## _OPTION_KEYS shortcuts always point at the option they visibly label.
func _refresh() -> void:
	_sell_button.text = "1. Sell scrap (%d) for $%d" % [
		Inventory.scrap, Inventory.scrap * money_per_scrap]
	_sell_button.disabled = Inventory.scrap <= 0
	_crane_button.text = "2. Take the crane out back ($%d a dig)" % crane_cost
	_stats.text = "Scrap %d   $%d   Spare parts %d" % [
		Inventory.scrap, Inventory.money, Inventory.spare_parts.size()]

func _set_line(text: String) -> void:
	_line.text = text

## Turn the player's whole scrap pile into cash. Returns the money earned.
func sell() -> int:
	if Inventory.scrap <= 0:
		_show_popup(empty_line)
		_set_line(empty_line)
		return 0
	var sold := Inventory.scrap
	var earned := Inventory.sell_scrap(money_per_scrap)
	_show_popup(sold_line % [sold, earned])
	_set_line(sold_line % [sold, earned])
	return earned

## Floating text over his head, same drift-and-fade as a looted trash prop.
func _show_popup(text: String) -> void:
	var popup := get_node_or_null("Popup") as Label
	if popup == null:
		return
	popup.text = text
	popup.visible = true
	popup.position = _popup_home
	popup.modulate.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position:y", _popup_home.y - POPUP_RISE, POPUP_LIFETIME)
	tween.parallel().tween_property(
			popup, "modulate:a", 0.0, POPUP_LIFETIME * 0.6).set_delay(POPUP_LIFETIME * 0.35)
	tween.tween_callback(func() -> void: popup.visible = false)
