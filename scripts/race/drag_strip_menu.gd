class_name DragStripMenu
extends Control
## The drag strip's front office: pick a tier, then either pay to drive the
## race yourself or bet on one car in a simulated field. Reached instead of
## race_drag_strip.tscn directly (see drag_strip.tscn's Entrance) — this
## screen decides the tier/car/bet, writes it to RaceProgression's pending_*
## fields, and change_scene_to_packed()s into the same race scene either
## way, since a fresh scene has no other way to receive parameters.
##
## Also resolves a bet: DragStripMenu spends the stake and writes
## last_bet_amount/last_bet_car_name before sending the player off to watch;
## single_lane_race_setup.gd (in bet mode, no player registered) writes back
## last_ai_race_winner/last_ai_race_field_names when the race ends and sends
## the player back here (RaceController.exit_scene_path), so the very next
## _ready() sees a result waiting and pays it out before the player does
## anything else.

const RACE_SCENE := "res://scenes/race/race_drag_strip.tscn"
const TIERS := [1, 2, 3, 4]
const TIER_NAMES := { 1: "Scrapper", 2: "Junker", 3: "Hot Rod", 4: "Chop Shop" }
const BET_AMOUNTS := [20, 50, 100]
const BET_FIELD_SIZE := 5
const BET_WIN_MULTIPLIER := 3

enum Page { TIER, MODE, DRIVE, BET_AMOUNT, BET_PICK }

@onready var _backdrop: WorkshopBackdrop = $Background
@onready var _money_label: Label = $MoneyPlate/MoneyLabel
@onready var _title_label: Label = $TitlePlate/TitleLabel
@onready var _info_label: Label = $InfoPlate/InfoLabel

@onready var _tier_page: Control = $TierPage
@onready var _tier_buttons: Array[ScrapButton] = [
	$TierPage/Tier1Button, $TierPage/Tier2Button, $TierPage/Tier3Button, $TierPage/Tier4Button,
]

@onready var _mode_page: Control = $ModePage
@onready var _drive_button: ScrapButton = $ModePage/DriveButton
@onready var _bet_button: ScrapButton = $ModePage/BetButton

@onready var _drive_page: Control = $DrivePage
@onready var _drive_car_view: CarView = $DrivePage/CarPreview
@onready var _drive_name_label: Label = $DrivePage/NamePlate/NameLabel
@onready var _drive_race_button: ScrapButton = $DrivePage/RaceButton

@onready var _bet_amount_page: Control = $BetAmountPage
@onready var _bet_amount_buttons: Array[ScrapButton] = [
	$BetAmountPage/Bet20Button, $BetAmountPage/Bet50Button, $BetAmountPage/Bet100Button,
]

@onready var _bet_pick_page: Control = $BetPickPage
@onready var _bet_field_list: HBoxContainer = $BetPickPage/FieldList
@onready var _bet_confirm_button: ScrapButton = $BetPickPage/ConfirmButton

const _BET_CARD_SCENE := preload("res://scenes/race/drag_strip_bet_card.tscn")

var _tier: int = 1
var _car_index: int = 0
var _bet_amount: int = 0
var _bet_field: Array[Dictionary] = []
var _bet_field_names: Array[String] = []
var _bet_pick_index: int = -1
var _bet_cards: Array[Node] = []

func _ready() -> void:
	if _resolve_pending_bet():
		SaveSystem.save_game()
	_car_index = clampi(Inventory.selected_index, 0, maxi(Inventory.owned_cars.size() - 1, 0))
	_refresh_money()
	_show_page(Page.TIER)

## If we're returning from a spectator bet race, RaceProgression's
## last_ai_race_winner is non-empty and there's a bet to settle — otherwise
## this is a no-op (e.g. arriving here fresh, or coming back from a driven
## race, which never sets last_ai_race_winner). Returns whether a bet was
## actually resolved, so the caller knows whether to save.
func _resolve_pending_bet() -> bool:
	if RaceProgression.last_ai_race_winner.is_empty():
		return false
	var won := RaceProgression.last_ai_race_winner == RaceProgression.last_bet_car_name
	if won:
		var payout := RaceProgression.last_bet_amount * BET_WIN_MULTIPLIER
		Inventory.money += payout
		Sfx.play(&"cash_register", -4.0)
		_flash_info("Your car won! +$%d" % payout)
	else:
		Sfx.play(&"denied", -6.0)
		_flash_info("Your car lost the bet.")
	RaceProgression.last_ai_race_winner = ""
	RaceProgression.last_ai_race_field_names = []
	RaceProgression.last_bet_amount = 0
	RaceProgression.last_bet_car_name = ""
	return true

func _flash_info(text: String) -> void:
	_info_label.text = text
	_info_label.visible = true

func _refresh_money() -> void:
	_money_label.text = "$%d" % Inventory.money

func _show_page(page: Page) -> void:
	_tier_page.visible = page == Page.TIER
	_mode_page.visible = page == Page.MODE
	_drive_page.visible = page == Page.DRIVE
	_bet_amount_page.visible = page == Page.BET_AMOUNT
	_bet_pick_page.visible = page == Page.BET_PICK
	match page:
		Page.TIER:
			_title_label.text = "Pick a Tier"
			for i in TIERS.size():
				_tier_buttons[i].selected = _tier == TIERS[i]
		Page.MODE:
			_title_label.text = "%s Tier — Drive or Bet?" % TIER_NAMES[_tier]
		Page.DRIVE:
			_title_label.text = "Choose Your Car"
			_refresh_drive_car()
		Page.BET_AMOUNT:
			_title_label.text = "Place Your Bet"
			for i in BET_AMOUNTS.size():
				_bet_amount_buttons[i].selected = _bet_amount == BET_AMOUNTS[i]
		Page.BET_PICK:
			_title_label.text = "Back a Car to Win"

func _on_tier_pressed(index: int) -> void:
	_tier = TIERS[index]
	_show_page(Page.MODE)

func _on_mode_back_pressed() -> void:
	_show_page(Page.TIER)

func _on_drive_pressed() -> void:
	_car_index = clampi(Inventory.selected_index, 0, maxi(Inventory.owned_cars.size() - 1, 0))
	_show_page(Page.DRIVE)

func _on_bet_pressed() -> void:
	_bet_amount = 0
	_show_page(Page.BET_AMOUNT)

func _on_drive_back_pressed() -> void:
	_show_page(Page.MODE)

func _on_drive_prev_pressed() -> void:
	_cycle_drive_car(-1)

func _on_drive_next_pressed() -> void:
	_cycle_drive_car(1)

func _cycle_drive_car(step: int) -> void:
	var count := Inventory.owned_cars.size()
	if count == 0:
		return
	_car_index = (_car_index + step + count) % count
	_refresh_drive_car()

func _refresh_drive_car() -> void:
	var cars := Inventory.owned_cars
	var fee := RaceProgression.entry_fee_for_tier(_tier)
	if cars.is_empty():
		_drive_name_label.text = "No cars in the garage"
		_drive_car_view.visible = false
		_drive_race_button.disabled = true
		return
	_drive_car_view.visible = true
	var car: CarModelData = cars[_car_index]
	_drive_car_view.build_from(car)
	_drive_name_label.text = "%s  (%d/%d)\nEntry fee: $%d" % [car.display_name, _car_index + 1, cars.size(), fee]
	_drive_race_button.disabled = not Inventory.can_afford(fee)

func _on_race_pressed() -> void:
	var fee := RaceProgression.entry_fee_for_tier(_tier)
	if not Inventory.spend_money(fee):
		Sfx.play(&"denied", -6.0)
		return
	Sfx.play(&"cash_register", -4.0)
	SaveSystem.save_game()
	RaceProgression.pending_tier = _tier
	RaceProgression.pending_car_index = _car_index
	RaceProgression.pending_include_player = true
	RaceProgression.pending_entry_fee = fee
	RaceProgression.pending_bet_field = []
	get_tree().change_scene_to_file(RACE_SCENE)

func _on_bet_amount_pressed(index: int) -> void:
	_bet_amount = BET_AMOUNTS[index]
	for i in _bet_amount_buttons.size():
		_bet_amount_buttons[i].selected = i == index

func _on_bet_amount_back_pressed() -> void:
	_show_page(Page.MODE)

func _on_bet_amount_next_pressed() -> void:
	if _bet_amount <= 0 or not Inventory.can_afford(_bet_amount):
		Sfx.play(&"denied", -6.0)
		return
	_roll_bet_field()
	_show_page(Page.BET_PICK)

func _roll_bet_field() -> void:
	_bet_field = RaceProgression.pick_rivals_for_tier(BET_FIELD_SIZE, _tier)
	_bet_field_names.clear()
	for card in _bet_cards:
		card.queue_free()
	_bet_cards.clear()
	var names := NameGen.random_names(_bet_field.size())
	_bet_pick_index = -1
	_bet_confirm_button.disabled = true
	for i in _bet_field.size():
		var rival: Dictionary = _bet_field[i]
		var car_name := "Car%d_%s_%s_%s" % [
			i,
			String(rival["body"]).get_file().get_basename(),
			String(rival["wheels"][0]).get_file().get_basename(),
			String(rival["engine"]).get_file().get_basename(),
		]
		_bet_field_names.append(car_name)
		var card := _BET_CARD_SCENE.instantiate()
		_bet_field_list.add_child(card)
		card.setup(names[i], _rival_car_model(rival))
		card.pressed.connect(_on_bet_card_pressed.bind(i))
		_bet_cards.append(card)

## Rival specs only carry scene paths (see RaceProgression.pick_rivals), so
## the full car shown on the bet card is assembled from throwaway PartData
## loads of those paths — the same fields PartFactory would read off a live
## car, just fetched without racing the car first.
static func _rival_car_model(rival: Dictionary) -> CarModelData:
	var model := CarModelData.new()
	model.body = PartDatabase.load_part_data(rival["body"]) as BodyPartData
	model.engine = PartDatabase.load_part_data(rival["engine"]) as EnginePartData
	var wheels: Array[WheelPartData] = []
	for wheel_path in rival["wheels"]:
		wheels.append(PartDatabase.load_part_data(wheel_path) as WheelPartData)
	model.wheels = wheels
	return model

func _on_bet_card_pressed(index: int) -> void:
	_bet_pick_index = index
	for i in _bet_cards.size():
		_bet_cards[i].set_picked(i == index)
	_bet_confirm_button.disabled = false

func _on_bet_pick_back_pressed() -> void:
	_show_page(Page.BET_AMOUNT)

func _on_bet_confirm_pressed() -> void:
	if _bet_pick_index < 0:
		return
	if not Inventory.spend_money(_bet_amount):
		Sfx.play(&"denied", -6.0)
		return
	Sfx.play(&"cash_register", -4.0)
	SaveSystem.save_game()
	RaceProgression.pending_tier = _tier
	RaceProgression.pending_car_index = -1
	RaceProgression.pending_include_player = false
	RaceProgression.pending_entry_fee = 0
	RaceProgression.pending_bet_field = _bet_field
	RaceProgression.last_bet_amount = _bet_amount
	RaceProgression.last_bet_car_name = _bet_field_names[_bet_pick_index]
	get_tree().change_scene_to_file(RACE_SCENE)
