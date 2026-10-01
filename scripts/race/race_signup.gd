class_name RaceSignup
extends RefCounted
## What DragStripMenu signed up for, taken out of RaceProgression's one-shot
## pending_* fields the moment a race scene starts, plus what happens when that
## race ends: a driven race records the result and pays the entry win, a
## watched bet race hands the winner back for the menu to settle. Shared by
## every venue's race setup, so they all treat money and bets the same way.
##
## A race reached without the menu (the debug T entrance) gets tier -1 and
## falls back to the campaign field, and never pays anything.

const MENU_SCENE := "res://scenes/race/drag_strip_menu.tscn"

var tier := -1
var car_index := -1
var include_player := true
var bet_field: Array[Dictionary] = []
var entry_fee := 0
## The name the player's car races under; empty when it isn't racing.
var player_car_name := ""
## Every rival's race name, in lane order, so a bet can be matched to the
## car that won.
var field_car_names: Array[String] = []

static func take_pending() -> RaceSignup:
	var signup := RaceSignup.new()
	signup.tier = RaceProgression.pending_tier
	signup.car_index = RaceProgression.pending_car_index
	signup.include_player = RaceProgression.pending_include_player
	signup.bet_field = RaceProgression.pending_bet_field
	signup.entry_fee = RaceProgression.pending_entry_fee
	RaceProgression.pending_tier = -1
	RaceProgression.pending_car_index = -1
	RaceProgression.pending_include_player = true
	RaceProgression.pending_entry_fee = 0
	RaceProgression.pending_bet_field = []
	return signup

## The car the player drives, or null on a bet race.
func player_car() -> CarModelData:
	if not include_player:
		return null
	if car_index >= 0 and car_index < Inventory.owned_cars.size():
		return Inventory.owned_cars[car_index]
	return Inventory.get_selected_car()

## The rivals to race: the exact field a bet was placed on, or a fresh one
## for the tier.
func rival_specs(count: int, course: RaceProgression.Course) -> Array[Dictionary]:
	if not bet_field.is_empty():
		return bet_field
	# The campaign ladder only exists on the drag roster; anything else
	# reached without the menu races tier 1.
	if tier <= 0 and course == RaceProgression.Course.DRAG:
		return RaceProgression.pick_rivals(count)
	return RaceProgression.pick_rivals_for_tier(count, maxi(tier, 1), course)

## DragStripMenu names its bet cards the same way, so the bet matches the car.
static func rival_car_name(slot: int, rival: Dictionary) -> String:
	return "Car%d_%s_%s_%s" % [
		slot,
		String(rival["body"]).get_file().get_basename(),
		String(rival["wheels"][0]).get_file().get_basename(),
		String(rival["engine"]).get_file().get_basename(),
	]

## Pays out when the race ends, and sends a menu race back to the menu.
func hook_up(race_controller: RaceController) -> void:
	if race_controller == null:
		return
	race_controller.race_ended.connect(_on_race_ended)
	if tier > 0:
		race_controller.exit_scene_path = MENU_SCENE

func _on_race_ended(winner_name: String) -> void:
	if not include_player:
		RaceProgression.last_ai_race_winner = winner_name
		RaceProgression.last_ai_race_field_names = field_car_names
		return
	if player_car_name.is_empty():
		return
	var player_won := winner_name == player_car_name
	RaceProgression.record_race(player_won)
	if player_won and entry_fee > 0:
		Inventory.money += entry_fee * RaceProgression.ENTRY_WIN_MULTIPLIER
		Sfx.play(&"cash_register", -4.0)
	SaveSystem.save_game()
