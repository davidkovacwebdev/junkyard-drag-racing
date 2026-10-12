class_name DragStripMenu
extends Control
## The front office shared by every race venue (drag strip, rally, hill
## climb, derby). The clerk opens with a small desk menu: race, bet, or (while
## "Ask Around" is on) ask about the Junkyard Treasure. Racing or betting
## then picks a tier, and either pays to drive the race yourself or bets on
## one car in a simulated field. Reached instead of
## the venue's race scene directly (see drag_strip.tscn's Entrance) — this
## screen decides the tier/car/bet, writes it to RaceProgression's pending_*
## fields, and change_scene_to_packed()s into the same race scene either
## way, since a fresh scene has no other way to receive parameters. Which race
## scene that is comes from RaceProgression.menu_race_scene, set by the
## RegistrationBooth the player walked into.
##
## Also resolves a bet: DragStripMenu spends the stake and writes
## last_bet_amount/last_bet_car_name before sending the player off to watch;
## single_lane_race_setup.gd (in bet mode, no player registered) writes back
## last_ai_race_winner/last_ai_race_field_names when the race ends and sends
## the player back here (RaceController.exit_scene_path), so the very next
## _ready() sees a result waiting and pays it out before the player does
## anything else.

const TIERS := [1, 2, 3, 4]
const TIER_NAMES := { 1: "Scrapper", 2: "Junker", 3: "Hot Rod", 4: "Chop Shop" }
const BET_MIN := 10
const BET_DEFAULT := 20
const BET_FIELD_SIZE := 5
const BET_WIN_MULTIPLIER := 3

enum Page { TIER, MODE, DRIVE, BET_AMOUNT, BET_PICK }

@onready var _backdrop: WorkshopBackdrop = $Background
@onready var _clerk: CharacterRig = $Content/Clerk
@onready var _clerk_speech_label: Label = $Content/SpeechPlate/SpeechLabel
@onready var _money_label: Label = $Content/MoneyPlate/MoneyLabel
@onready var _title_label: Label = $Content/TitlePlate/TitleLabel
@onready var _info_label: Label = $Content/InfoPlate/InfoLabel

@onready var _tier_page: Control = $Content/TierPage
@onready var _tier_buttons: Array[ScrapButton] = [
	$Content/TierPage/Tier1Button, $Content/TierPage/Tier2Button, $Content/TierPage/Tier3Button, $Content/TierPage/Tier4Button,
]

@onready var _mode_page: Control = $Content/ModePage
@onready var _drive_button: ScrapButton = $Content/ModePage/DriveButton
@onready var _bet_button: ScrapButton = $Content/ModePage/BetButton

@onready var _drive_page: Control = $Content/DrivePage
@onready var _drive_car_view: CarView = $Content/DrivePage/CarPreview
@onready var _drive_name_label: Label = $Content/DrivePage/NamePlate/NameLabel
@onready var _drive_race_button: ScrapButton = $Content/DrivePage/RaceButton

@onready var _bet_amount_page: Control = $Content/BetAmountPage
@onready var _bet_amount_label: Label = $Content/BetAmountPage/AmountPlate/AmountLabel
@onready var _bet_decrease_buttons: Array[ScrapButton] = [
	$Content/BetAmountPage/Minus100Button, $Content/BetAmountPage/Minus10Button,
]
@onready var _bet_increase_buttons: Array[ScrapButton] = [
	$Content/BetAmountPage/Plus10Button, $Content/BetAmountPage/Plus100Button, $Content/BetAmountPage/AllInButton,
]

@onready var _bet_pick_page: Control = $Content/BetPickPage
@onready var _bet_field_list: HBoxContainer = $Content/BetPickPage/FieldList
@onready var _bet_confirm_button: ScrapButton = $Content/BetPickPage/ConfirmButton

const _BET_CARD_SCENE := preload("res://scenes/race/drag_strip_bet_card.tscn")
## Who's behind the counter at each venue, by its name; anywhere else gets
## the drag strip's clerk from the scene.
const CLERKS := {
	"Rally": preload("res://characters/race_clerk_rally.tres"),
	"Hill Climb": preload("res://characters/race_clerk_hill.tres"),
	"Demolition Derby": preload("res://characters/race_clerk_derby.tres"),
}
const CLERK_IDLE_BOB_PIXELS := 2.0
const CLERK_TALK_SQUASH := 0.03

var _tier: int = 1
## Which way the desk menu went: betting on the field, or driving it.
var _betting: bool = false
## "Ask Around" (TreasureRumors), on the desk menu; and the way back to it
## from the tier page.
var _ask_button: ScrapButton
var _tier_back_button: ScrapButton
var _car_index: int = 0
var _bet_amount: int = 0
var _bet_field: Array[Dictionary] = []
var _bet_field_names: Array[String] = []
## The driver name on each bet card, in field order.
var _bet_driver_names: Array[String] = []
var _bet_pick_index: int = -1
var _bet_cards: Array[Node] = []
## Which bet card is Roge Roger's, or -1 when he isn't in the field.
var _roger_index: int = -1
var _clerk_speech := SpeechPlayer.new()
var _clerk_rest := Vector2.ZERO
var _clerk_scale := Vector2.ONE
var _time := 0.0
## Spike's mid-flex (see `_flex()`).
var _flexing := false

func _ready() -> void:
	add_child(_clerk_speech)
	SpeechScroll.wrap(_clerk_speech_label)
	if CLERKS.has(RaceProgression.menu_venue_name):
		_clerk.set_character(CLERKS[RaceProgression.menu_venue_name])
	_clerk_rest = _clerk.position
	_clerk_scale = _clerk.scale
	_car_index = clampi(Inventory.selected_index, 0, maxi(Inventory.owned_cars.size() - 1, 0))
	_build_desk()
	_refresh_money()
	_show_page(Page.MODE)
	if _resolve_pending_bet():
		_refresh_money()
		SaveSystem.save_game()

## The desk menu is the old Drive / Bet page, put first: Race and Bet, the
## rumours question under them, and no back button (the screen's own Back
## leaves). The tier page gets a way back to it.
func _build_desk() -> void:
	_drive_button.text = "Race"
	_bet_button.text = "Bet"
	($Content/ModePage/BackButton as Control).visible = false
	_ask_button = ScrapButton.new()
	_ask_button.text = TreasureRumors.ASK_LINE
	_ask_button.font_size = 18
	_ask_button.tilt_degrees = -1.0
	_ask_button.jitter_seed = 64
	_ask_button.position = Vector2(216.0, 390.0)
	_ask_button.size = Vector2(520.0, 56.0)
	_ask_button.pressed.connect(_on_ask_pressed)
	_mode_page.add_child(_ask_button)
	_tier_back_button = ScrapButton.new()
	_tier_back_button.text = "< Back"
	_tier_back_button.font_size = 18
	_tier_back_button.tilt_degrees = -1.0
	_tier_back_button.jitter_seed = 65
	_tier_back_button.position = Vector2(30.0, 560.0)
	_tier_back_button.size = Vector2(130.0, 40.0)
	_tier_back_button.pressed.connect(_show_page.bind(Page.MODE))
	_tier_page.add_child(_tier_back_button)
	# The drive and bet-amount pages now step back to the tier, not the mode.
	for back: ScrapButton in [$Content/DrivePage/BackButton, $Content/BetAmountPage/BackButton]:
		back.text = "< Tier"

## Each venue's clerk has heard their own bit about the treasure.
const RUMOR_KEYS := {
	"Rally": TreasureRumors.CLERK_RALLY,
	"Hill Climb": TreasureRumors.CLERK_HILL,
	"Demolition Derby": TreasureRumors.CLERK_DERBY,
}

func _on_ask_pressed() -> void:
	var key: StringName = RUMOR_KEYS.get(RaceProgression.menu_venue_name, TreasureRumors.CLERK_DRAG)
	_clerk_says(TreasureRumors.answer(key))
	if key == TreasureRumors.CLERK_DERBY:
		_flex()

## Spike flexes his biceps once he's said his piece: his left arm swaps for
## a raised FlexArm that pumps up twice, then drops back.
func _flex() -> void:
	if _flexing:
		return
	_flexing = true
	while _clerk_speech.is_typing():
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	var own_arm := _clerk.find_child("ArmLeft", true, false) as Polygon2D
	var arm := FlexArm.new()
	if own_arm != null:
		arm.sleeve = own_arm.color
		own_arm.visible = false
	var skull := _clerk.find_child("Skull", true, false) as Polygon2D
	if skull != null:
		arm.skin = skull.color
	arm.z_index = 2
	_clerk.add_child(arm)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 2:
		tween.tween_callback(Sfx.play.bind(&"muscle_flex", -4.0, 0.05))
		tween.tween_property(arm, "bulge", 1.0, 0.25)
		tween.tween_interval(0.35)
		tween.tween_property(arm, "bulge", 0.2, 0.2)
	tween.tween_interval(0.3)
	await tween.finished
	arm.queue_free()
	if is_instance_valid(own_arm):
		own_arm.visible = true
	_flexing = false

## The clerk bobs behind the counter, and squashes while talking.
func _process(delta: float) -> void:
	_time += delta
	var squash := sin(_time * TAU * 6.0) * CLERK_TALK_SQUASH if _clerk_speech.is_typing() else 0.0
	_clerk.position.y = _clerk_rest.y + sin(_time * TAU * 0.6) * CLERK_IDLE_BOB_PIXELS
	_clerk.scale = Vector2(_clerk_scale.x * (1.0 - squash), _clerk_scale.y * (1.0 + squash))

func _clerk_says(line: String) -> void:
	_clerk_speech.speak(_clerk_speech_label, line, _clerk.character_data)

## If we're returning from a spectator bet race, RaceProgression's
## last_ai_race_winner is non-empty and there's a bet to settle — otherwise
## this is a no-op (e.g. arriving here fresh, or coming back from a driven
## race, which never sets last_ai_race_winner). Returns whether a bet was
## actually resolved, so the caller knows whether to save.
func _resolve_pending_bet() -> bool:
	var torn := RaceProgression.last_bet_torn
	if RaceProgression.last_ai_race_winner.is_empty() and not torn:
		return false
	var won := not torn and RaceProgression.last_ai_race_winner == RaceProgression.last_bet_car_name
	var on_roger := RaceProgression.last_bet_on_roger
	if on_roger:
		Quests.set_note(RaceProgression.ROGER_QUEST, "won" if won else "lost")
		Quests.goal_met(RaceProgression.ROGER_QUEST)
	if won:
		var payout := RaceProgression.last_bet_amount * BET_WIN_MULTIPLIER
		Inventory.money += payout
		Sfx.play(&"cash_register", -4.0)
		_flash_info("Your car won! +$%d" % payout)
		_clerk_says("Well I'll be. Your pick came in. Here's yer $%d." % payout)
	else:
		Sfx.play(&"denied", -6.0)
		_flash_info("You tore up your ticket." if torn else "Your car lost the bet.")
		if torn:
			_clerk_says("Tore it up, huh? House keeps the stake all the same.")
		else:
			_clerk_says("Roge Roger? HA! Ya might as well've burned it." if on_roger
					else "Tough luck. House keeps the stake.")
	RaceProgression.last_ai_race_winner = ""
	RaceProgression.last_ai_race_field_names = []
	RaceProgression.last_bet_amount = 0
	RaceProgression.last_bet_car_name = ""
	RaceProgression.last_bet_on_roger = false
	RaceProgression.last_bet_torn = false
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
		Page.MODE:
			_title_label.text = RaceProgression.menu_venue_name
			_ask_button.visible = TreasureRumors.can_ask()
			_clerk_says("What'll it be? Race, or put money on somebody who can?")
		Page.TIER:
			_title_label.text = "%s — Pick a Tier" % RaceProgression.menu_venue_name
			for i in TIERS.size():
				var tier: int = TIERS[i]
				_tier_buttons[i].selected = _tier == tier
				_tier_buttons[i].text = TIER_NAMES[tier] if _betting \
						else "%s — $%d" % [TIER_NAMES[tier], RaceProgression.entry_fee_for_tier(tier)]
			_clerk_says("Bettin'? Pick a class to put yer money on." if _betting
					else "Signin' up? Pick a class. Bigger fee, meaner junk.")
		Page.DRIVE:
			_title_label.text = "Choose Your Car"
			_refresh_drive_car()
			var fee := RaceProgression.entry_fee_for_tier(_tier)
			var rules := RaceProgression.menu_venue_rules
			if rules.is_empty():
				rules = "Rivals do it in about %d seconds." % roundi(RaceProgression.par_time_for_tier(_tier))
			_clerk_says("No car? Can't race a shopping list." if Inventory.owned_cars.is_empty()
					else "%s. $%d to enter, a win pays $%d. %s" % [
					TIER_NAMES[_tier], fee, fee * RaceProgression.ENTRY_WIN_MULTIPLIER, rules])
		Page.BET_AMOUNT:
			_title_label.text = "Place Your Bet"
			_set_bet_amount(_bet_amount if _bet_amount > 0 else BET_DEFAULT)
			_clerk_says("How much ya puttin' down? Pays %dx." % BET_WIN_MULTIPLIER)
		Page.BET_PICK:
			_title_label.text = "Back a Car to Win"
			_clerk_says("Pick a winner. That's Roge Roger in there, if ya can believe it." if _roger_index >= 0
					else "Pick a winner. No refunds.")

func _on_tier_pressed(index: int) -> void:
	_tier = TIERS[index]
	if _betting:
		_bet_amount = 0
		_show_page(Page.BET_AMOUNT)
	else:
		_car_index = clampi(Inventory.selected_index, 0, maxi(Inventory.owned_cars.size() - 1, 0))
		_show_page(Page.DRIVE)

func _on_mode_back_pressed() -> void:
	_show_page(Page.MODE)

func _on_drive_pressed() -> void:
	_betting = false
	_show_page(Page.TIER)

func _on_bet_pressed() -> void:
	_betting = true
	_show_page(Page.TIER)

func _on_drive_back_pressed() -> void:
	_show_page(Page.TIER)

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
		_clerk_says("That ain't enough cash, pal.")
		return
	Sfx.play(&"cash_register", -4.0)
	SaveSystem.save_game()
	RaceProgression.pending_tier = _tier
	RaceProgression.pending_car_index = _car_index
	RaceProgression.pending_include_player = true
	RaceProgression.pending_entry_fee = fee
	RaceProgression.pending_bet_field = []
	RaceProgression.pending_bet_names = []
	SceneLoader.change_scene(RaceProgression.menu_race_scene)

## Any amount from BET_MIN up to everything the player has.
func _set_bet_amount(amount: int) -> void:
	_bet_amount = clampi(amount, mini(BET_MIN, Inventory.money), Inventory.money)
	_bet_amount_label.text = "$%d" % _bet_amount
	for button in _bet_decrease_buttons:
		button.disabled = _bet_amount <= BET_MIN
	for button in _bet_increase_buttons:
		button.disabled = _bet_amount >= Inventory.money

func _on_bet_step_pressed(step: int) -> void:
	_set_bet_amount(_bet_amount + step)

func _on_bet_all_in_pressed() -> void:
	_set_bet_amount(Inventory.money)
	_clerk_says("The whole wad?! Ya got guts, pal.")

func _on_bet_amount_back_pressed() -> void:
	_show_page(Page.TIER)

func _on_bet_amount_next_pressed() -> void:
	if _bet_amount < BET_MIN or not Inventory.can_afford(_bet_amount):
		Sfx.play(&"denied", -6.0)
		_clerk_says("Minimum's $%d. Ya can't cover that, pal." % BET_MIN)
		return
	_roll_bet_field()
	_show_page(Page.BET_PICK)

func _roll_bet_field() -> void:
	_bet_field = RaceProgression.pick_rivals_for_tier(BET_FIELD_SIZE, _tier, RaceProgression.menu_course)
	_bet_field_names.clear()
	for card in _bet_cards:
		card.queue_free()
	_bet_cards.clear()
	var names := NameGen.random_names(_bet_field.size())
	# Roge Roger takes one lane, in his hopeless car.
	_roger_index = -1
	if RaceProgression.roger_is_racing(_tier, RaceProgression.menu_venue_name):
		_roger_index = randi() % _bet_field.size()
		_bet_field[_roger_index] = RaceProgression.roger_spec()
		names[_roger_index] = RaceProgression.ROGER_NAME
	_bet_driver_names = names
	_bet_pick_index = -1
	_bet_confirm_button.disabled = true
	for i in _bet_field.size():
		var rival: Dictionary = _bet_field[i]
		_bet_field_names.append(RaceSignup.rival_car_name(i, rival))
		var card := _BET_CARD_SCENE.instantiate()
		_bet_field_list.add_child(card)
		card.setup(names[i], RaceProgression.rival_car_model(rival))
		card.pressed.connect(_on_bet_card_pressed.bind(i))
		_bet_cards.append(card)

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
	RaceProgression.pending_bet_names = _bet_driver_names
	RaceProgression.last_bet_amount = _bet_amount
	RaceProgression.last_bet_car_name = _bet_field_names[_bet_pick_index]
	RaceProgression.last_bet_on_roger = _bet_pick_index == _roger_index
	SceneLoader.change_scene(RaceProgression.menu_race_scene)
