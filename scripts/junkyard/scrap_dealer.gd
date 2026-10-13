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
## During "Metal Head" he has one more option: asking him where to get a metal
## detector plays DetectorAskCutscene at the counter, which finishes it.
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
## Said while the crane is down after it came down on Grandpa (CraneWreck).
## `%s` becomes how long until it's fixed ("2 days").
@export var wrecked_line: String = "Crane's busted, pal. Fell over. You heard. Repair guy says it'll be fixed in %s."
@export var digger_lent_line: String = "She's all yours. Bring her back when you're done."
@export var digger_back_line: String = "Back in one piece. Mostly. Thanks."
@export var digger_broke_line: String = "It's $%d to borrow her, pal. Come back with the cash."
## Handing back Grandpa's metal detector, battery wired in ("Charged Up").
@export var detector_ready_line: String = "There ya go. Battery's in, and she beeps. Good as new. Well, good as old."
## Said when the player turns up with Grandpa's quest: the crane opens.
@export var grandpa_sent_line: String = "Eugen sent ya? Ha! That old drunk. Forty years we ran that crane together. Alright: $%d a go, crane's out back. Whatever the claw comes up with, it's yours."

## The quest that opens the crane.
const CRANE_QUEST := &"crane_guy"
## "Metal Head": asking him where to get a metal detector (DetectorAskCutscene).
const DETECTOR_QUEST := &"metal_head"
const DETECTOR_SCENE_PATH := "res://cutscenes/detector_ask.tres"
## "Scrap Juice": asking him for a battery (BatteryAskCutscene). "Fish It
## Out" makes the crane free; "Charged Up" is picking the detector up here.
const BATTERY_QUEST := &"junkyard_batteries"
const BATTERY_SCENE_PATH := "res://cutscenes/battery_ask.tres"
const MOTOR_QUEST := &"toy_motor"
const PICKUP_QUEST := &"detector_pickup"
const CHARGED_DETECTOR := preload("res://items/metal_detector_charged.tres")
## "Heavy Machinery": asking him for something to dig with
## (DiggerRevealCutscene), which lends the player the yard's digger.
const DIG_GEAR_QUEST := &"dig_gear"
const DIGGER_SCENE_PATH := "res://cutscenes/digger_reveal.tres"
## Once the treasure's dug up, the digger's his to lend: this much a go.
@export var digger_rent: int = 100

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
	if pen_scene.is_empty() or not crane_unlocked() or CraneWreck.is_down():
		Sfx.play(&"denied", -6.0, 0.0)
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
	elif Quests.has_quest(PICKUP_QUEST):
		_hand_back_detector()
	elif CraneWreck.is_down():
		var days := CraneWreck.days_left()
		_dialog.say(wrecked_line % ("%d day%s" % [days, "" if days == 1 else "s"]))
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
	var options := [
		CharacterDialog.Option.new("Sell scrap (%d) for $%d" % [
				Inventory.scrap, Inventory.scrap * money_per_scrap],
				_on_sell_pressed, Inventory.scrap <= 0),
		_crane_option(),
	]
	if TreasureRumors.can_ask():
		options.append(TreasureRumors.option(_dialog, TreasureRumors.SCRAP_DEALER))
	if Quests.has_quest(DETECTOR_QUEST):
		options.append(CharacterDialog.Option.new("Ask about a metal detector", _ask_about_detector))
	if Quests.has_quest(BATTERY_QUEST):
		options.append(CharacterDialog.Option.new("Ask about batteries", _ask_about_batteries))
	if Quests.has_quest(DIG_GEAR_QUEST):
		options.append(CharacterDialog.Option.new("Ask for something to dig with", _ask_about_digging))
	if WorldState.is_claimed(DiggerRig.RENTED):
		options.append(CharacterDialog.Option.new("Give the digger back", _return_digger))
	elif Quests.is_complete(DiggerRig.DIG_QUEST):
		options.append(CharacterDialog.Option.new("Borrow the digger ($%d)" % digger_rent, _rent_digger,
				Inventory.money < digger_rent))
	options.append(CharacterDialog.Option.new("Walk away", _on_leave_pressed))
	_dialog.set_options(options, animate)
	_dialog.set_note("Scrap %d   $%d   Spare parts %d" % [
		Inventory.scrap, Inventory.money, Inventory.spare_parts.size()])

## The crane button: open, not for rent yet, or busted for a few days.
func _crane_option() -> CharacterDialog.Option:
	if CraneWreck.is_down():
		var days := CraneWreck.days_left()
		return CharacterDialog.Option.new("The crane (busted, fixed in %d day%s)" % [days, "" if days == 1 else "s"],
				_on_crane_pressed, true)
	if not crane_unlocked():
		return CharacterDialog.Option.new("The crane (not for rent)", _on_crane_pressed, true)
	if Quests.has_quest(MOTOR_QUEST):
		return CharacterDialog.Option.new("Take the crane out back (free, for the toy motor)", _on_crane_pressed)
	return CharacterDialog.Option.new("Take the crane out back ($%d a dig)" % crane_cost, _on_crane_pressed)

## "Metal Head": the two of them talk it over at the counter, and he sends
## the player home to Grandpa's tool shed.
func _ask_about_detector() -> void:
	await _counter_scene(DETECTOR_SCENE_PATH, DETECTOR_QUEST)

## "Scrap Juice": he points the player at the toy car motor in today's load.
func _ask_about_batteries() -> void:
	await _counter_scene(BATTERY_SCENE_PATH, BATTERY_QUEST)

## "Heavy Machinery": he lends the player the digger.
func _ask_about_digging() -> void:
	await _counter_scene(DIGGER_SCENE_PATH, DIG_GEAR_QUEST)

## The digger on loan: the player drives it instead of their car until
## they bring it back.
func _rent_digger() -> void:
	if not Inventory.spend_money(digger_rent):
		Sfx.play(&"denied", -6.0, 0.0)
		_dialog.say(digger_broke_line % digger_rent)
		return
	Sfx.play(&"cash_register", -4.0, 0.0)
	WorldState.mark_claimed(DiggerRig.RENTED)
	_dialog.say(digger_lent_line)
	_refresh()
	SaveSystem.save_game()

func _return_digger() -> void:
	WorldState.unclaim(DiggerRig.RENTED)
	Sfx.play(&"door_close", -4.0, 0.0)
	_dialog.say(digger_back_line)
	_refresh()
	SaveSystem.save_game()

## Plays the counter talk at `path` with him in it, then finishes `quest_id`.
func _counter_scene(path: String, quest_id: StringName) -> void:
	_close()
	var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as CoinsCutscene
	if scene != null:
		scene.npc_rig = _character
		await Cutscenes.play(scene)
	Quests.complete(quest_id)
	SaveSystem.save_game()

## "Charged Up": the detector comes back with the toy motor's battery in it.
func _hand_back_detector() -> void:
	if Inventory.is_trunk_full():
		Sfx.play(&"denied", -6.0, 0.0)
		_dialog.say("Got your detector here, but your trunk's full. Make some room.")
		return
	Inventory.give_item(CHARGED_DETECTOR)
	Sfx.play(&"detector_beep", -6.0, 0.0)
	_dialog.say_about(PICKUP_QUEST, detector_ready_line)
	Quests.complete(PICKUP_QUEST)
	SaveSystem.save_game()

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
