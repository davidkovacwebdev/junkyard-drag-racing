class_name ChestOpeningCutscene
extends CoinsCutscene
## "Show and Tell", at the junkyard: the player drives in with the treasure
## chest and sets it down in front of the man at the counter (Vern, or
## whoever has his job now). He can't believe it. The player rings Chad, who
## squeaks down the phone that he's on his way. A little later he's there,
## and the chest is opened, seen from straight above (ChestTopView): a big
## boat engine, and gold nuggets. Played by JunkyardStory, which then hands
## over the Treasure Boat Engine and the gold's $3000 and finishes the
## quest.
##
## The words live in res://cutscenes/chest_opening.tres; edit them in the
## inspector.

const ID := &"chest_opening"
const CHAD := preload("res://characters/chad.tres")
const CHEST_ICON := preload("res://scenes/items/icons/item_treasure_chest.tscn")
const ENGINE_PATH := "res://scenes/parts/engines/engine_treasure_propeller.tscn"
## Chad on the phone: his own voice, squeakier still down the line.
const PHONE_PITCH := 1.4

@export var real_line: String = "Woah, is it real? Whatt? Eugen was right?"
@export var call_line: String = "It seems so.. Lemme call Chad."
@export var right_away_line: String = "I'll be there right away *smooch*"
@export var later_card: String = "A little later..."
@export var gold_card: String = "Gold nuggets: +$3000"
## The gold's worth, for the card (JunkyardStory pays it).
@export var gold_money: int = 3000

@export_group("Staging")
## Where the chest is set down, between the two of them, from the man.
@export var chest_offset := Vector2(65.0, 14.0)
@export var chest_scale: float = 1.4

func _init() -> void:
	id = ID

func play() -> void:
	if not await stage():
		return
	# The chest goes down between them.
	var chest := CHEST_ICON.instantiate() as Node2D
	chest.scale = Vector2.ONE * chest_scale
	chest.global_position = npc_rig.global_position + chest_offset * Vector2(_side(), 1.0)
	Cutscenes.get_tree().current_scene.add_child(chest)
	Cutscenes.sound(&"wood_clonk", -4.0)
	await Cutscenes.wait(0.4)
	Cutscenes.hop(npc, 18.0)
	await npc_says(real_line)
	await i_say(call_line)

	# Chad, on the phone.
	if player != null:
		await Cutscenes.play_tween(player.hold_phone(true))
	Cutscenes.sound(&"phone_dial", -8.0)
	await Cutscenes.wait(1.6)
	Cutscenes.sound(&"phone_beep", -8.0)
	var on_phone := CHAD.duplicate() as CharacterData
	on_phone.voice_pitch_hz = CHAD.voice_pitch_hz * PHONE_PITCH
	await Cutscenes.subtitle("%s (on the phone)" % CHAD.display_name, on_phone, right_away_line, null)
	Cutscenes.sound(&"flag_kiss", -6.0)
	await Cutscenes.wait(0.6)
	Cutscenes.sound(&"phone_beep", -8.0)
	Cutscenes.clear_subtitle()
	if player != null:
		await Cutscenes.play_tween(player.hold_phone(false))

	# A little later: Chad's here.
	await Cutscenes.fade_out(0.5)
	await Cutscenes.title_card(later_card, 1.5)
	var chad := Cutscenes.spawn_actor(CHAD, npc_rig.global_position + Vector2(-90.0 * _side(), 20.0), _side() > 0.0)
	await Cutscenes.fade_in(0.5)
	chad.wink(-6.0)
	await Cutscenes.wait(0.8)

	# Open it up, seen from above.
	await Cutscenes.fade_out(0.3)
	var top := ChestTopView.new()
	Cutscenes.get_tree().current_scene.add_child(top)
	await Cutscenes.fade_in(0.3)
	await Cutscenes.wait(0.6)
	if not Cutscenes.is_skipping():
		await top.open()
	await Cutscenes.wait(2.0)
	await Cutscenes.fade_out(0.3)
	top.queue_free()
	chest.queue_free()
	await Cutscenes.fade_in(0.3)

	# What was in it.
	await Cutscenes.part_card(PartDatabase.load_part_data(ENGINE_PATH), 3.0)
	Cutscenes.sound(&"cash_register", -4.0)
	await Cutscenes.title_card(gold_card, 2.0)
	await Cutscenes.fade_out(0.4)
	unstage()

## Which way the player stands from the man: 1 to his right, -1 to his left.
func _side() -> float:
	if player == null or npc == null:
		return 1.0
	return 1.0 if player.global_position.x > npc.global_position.x else -1.0
