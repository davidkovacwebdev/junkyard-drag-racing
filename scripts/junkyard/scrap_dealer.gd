class_name ScrapDealer
extends StaticBody2D
## The junkyard's buyer: the punker from the character creator, standing beside
## the crane. Drive up to him and left-click to sell the whole scrap pile for
## cash.
##
## Duck-typed for PlayerCar the same way TrashProp is:
##   - a non-empty `display_name` makes him an interaction target at all,
##   - `uses_click_interaction()` keeps the space bar out of it (he's
##     click-only, per the brief) while still letting the tooltip point at him,
##   - `get_interact_prompt()` supplies the wording, because PlayerCar's default
##     tooltip talks about the space key.
## Being a StaticBody2D means two things: the car can't drive through him, and
## the click has an actual shape to hit — PlayerCar's click is a point query
## against the physics world, not a mouse-over test.
##
## He doesn't carry a copy of the punker's parts: the `Character` child is a
## CharacterRig pointed at res://characters/punker.tres, so editing that .tres
## in the Character Creator changes this guy too.

@export var display_name: String = "Scrap Dealer"
## Cash paid per unit of scrap. 1 keeps the loot numbers readable.
@export var money_per_scrap: int = 1

@export_group("Lines")
@export var empty_line: String = "Nothin' worth sellin', friend."
@export var sold_line: String = "That's %d scrap - here's $%d."

const POPUP_RISE := 54.0
const POPUP_LIFETIME := 1.4

## Where the Popup label rests, captured from the scene in _ready().
var _popup_home: Vector2 = Vector2.ZERO

func _ready() -> void:
	var popup := get_node_or_null("Popup") as Label
	if popup != null:
		_popup_home = popup.position

## PlayerCar skips its space-press activation for targets that answer yes here.
func uses_click_interaction() -> bool:
	return true

## Wording for PlayerCar's proximity tooltip. Shows the haul on offer, so the
## prompt doubles as the "how much scrap have I got" readout at the yard.
func get_interact_prompt() -> String:
	return "%s: left-click to sell scrap (%d)" % [display_name, Inventory.scrap]

## Called by PlayerCar on a left-click. Kept separate from `sell()` so a future
## dealer could do something else without touching the car.
func interact(_actor: Node = null) -> void:
	sell()

## Turn the player's whole scrap pile into cash. Returns the money earned.
func sell() -> int:
	if Inventory.scrap <= 0:
		_show_popup(empty_line)
		return 0
	var sold := Inventory.scrap
	var earned := Inventory.sell_scrap(money_per_scrap)
	_show_popup(sold_line % [sold, earned])
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
