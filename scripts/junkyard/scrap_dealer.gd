class_name ScrapDealer
extends StaticBody2D
## The junkyard's buyer, who also runs the crane: Vern, Grandpa's old crane
## buddy, or once the claw has had him, whichever crane worker is on shift
## (CraneWorkerGenerator.current_operator(), the same guy standing in the pen). Drive up to him and press E (or left-click) for the dialog,
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
## He doesn't carry a copy of anyone's parts: the `Character` child is a
## CharacterRig swapped to the current operator on ready, and his name is
## theirs.
##
## The crane is locked until Grandpa's "Claw Machine" quest: it's Vern's
## crane, Grandpa's old buddy, and he doesn't rent it to strangers. Talking to him with that quest in
## the log finishes it and opens the crane for good.
##
## The dialog is the standard CharacterDialog (scenes/ui/character_dialog.tscn)
## instanced into this scene, so the whole dealer (art, collision, dialog) is
## still one `instantiate()` for anyone building a second yard.

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
## Said while the crane is still locked (no "Claw Machine" yet).
@export var locked_line: String = "Buyin' scrap. The crane? Not for rent, pal. Not to strangers."
## Said when the player turns up with Grandpa's quest: the crane opens.
@export var grandpa_sent_line: String = "Eugen sent ya? Ha! That old drunk. Forty years we ran that crane together. Alright: $%d a go, crane's out back. Whatever the claw comes up with, it's yours."

## The quest that opens the crane.
const CRANE_QUEST := &"crane_guy"

const POPUP_RISE := 54.0
const POPUP_LIFETIME := 1.4

## Where the Popup label rests, captured from the scene in _ready().
var _popup_home: Vector2 = Vector2.ZERO
## The car that opened the dialog, so it can be closed when that car drives off.
var _actor: Node2D = null

@onready var _dialog: CharacterDialog = $Dialog
@onready var _character: CharacterRig = $Character

func _ready() -> void:
	var operator := CraneWorkerGenerator.current_operator()
	_character.set_character(operator)
	display_name = operator.display_name
	var popup := get_node_or_null("Popup") as Label
	if popup != null:
		_popup_home = popup.position
	_close()

func _process(_delta: float) -> void:
	if not _dialog.is_open():
		return
	# Talk to the car in front of you, not to the empty stall it just left.
	if not is_instance_valid(_actor) \
			or global_position.distance_to(_actor.global_position) > dialog_range:
		_close()

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
	if pen_scene.is_empty() or not crane_unlocked():
		return
	_close()
	SaveSystem.save_game()
	SceneLoader.change_scene(pen_scene)

func _on_leave_pressed() -> void:
	_close()

## Pop the dialog up on the car we're talking to, primed with his opening line.
func _open() -> void:
	if _dialog.is_open():
		return
	_dialog.open(display_name, _character.character_data)
	if Quests.has_quest(CRANE_QUEST):
		Quests.complete(CRANE_QUEST)
		_dialog.say(grandpa_sent_line % crane_cost)
	elif crane_unlocked():
		_dialog.say(PlayerProfile.fill(_character.character_data.idle_line(greet_line)))
	else:
		_dialog.say(locked_line)
	_refresh(true)

## Whether he lets the player at the crane: only once Grandpa vouched.
static func crane_unlocked() -> bool:
	return Quests.is_complete(CRANE_QUEST)

## Hide it and forget the car.
func _close() -> void:
	_actor = null
	if is_instance_valid(_dialog):
		_dialog.close()

## Reflect the world in the dialog: what he'd pay for the scrap, what a dig
## costs, and what the player is carrying.
func _refresh(animate: bool = false) -> void:
	_dialog.set_options([
		CharacterDialog.Option.new("Sell scrap (%d) for $%d" % [
				Inventory.scrap, Inventory.scrap * money_per_scrap],
				_on_sell_pressed, Inventory.scrap <= 0),
		CharacterDialog.Option.new("Take the crane out back ($%d a dig)" % crane_cost
				if crane_unlocked() else "The crane (not for rent)",
				_on_crane_pressed, not crane_unlocked()),
		CharacterDialog.Option.new("Walk away", _on_leave_pressed),
	], animate)
	_dialog.set_note("Scrap %d   $%d   Spare parts %d" % [
		Inventory.scrap, Inventory.money, Inventory.spare_parts.size()])

func _set_line(text: String) -> void:
	_dialog.say(text)

## Turn the player's whole scrap pile into cash. Returns the money earned.
func sell() -> int:
	if Inventory.scrap <= 0:
		Sfx.play(&"denied", -6.0, 0.0)
		_show_popup(empty_line)
		_set_line(empty_line)
		return 0
	var sold := Inventory.scrap
	var earned := Inventory.sell_scrap(money_per_scrap)
	Sfx.play(&"cash_register", -4.0, 0.0)
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
