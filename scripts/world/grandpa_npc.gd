class_name GrandpaNpc
extends StaticBody2D
## Grandpa, parked in his wheelchair next to the player's car. Left alone he
## leans back for a sip of beer every few seconds.
##
## Drive up and press E to talk (the standard CharacterDialog). He's a quest
## giver: if one of his quests is ready to hand in, talking to him finishes
## it and pays the reward; if one is still in progress he nags; otherwise he
## wants to be left alone. Duck-typed for PlayerCar like the scrap dealer: a
## `display_name`, `get_interact_prompt()` and `interact()`, on a body the car
## can bump into. He holds still while a
## cutscene runs, so the scene can call `sip()`, `twitch()` and `bang()` on its
## own beats instead.
##
## The bent wrench only comes out for `bang()` (the wrench quest's scene);
## `show_wrench()` keeps it in his hand.
##
## `actor` is a plain CutsceneActor, so cutscenes can hand it to
## Cutscenes.subtitle() for the talking squash like any spawned actor.

const CHARACTER := preload("res://characters/grandpa.tres")
const DIALOG_SCENE := preload("res://scenes/ui/character_dialog.tscn")
## The wheelchair's footprint on the ground, which the car bumps into.
const BODY_SIZE := Vector2(80.0, 40.0)
const WRENCH := preload("res://scenes/characters/props/bent_wrench.tscn")
## Same size as every other character standing in the world.
const ACTOR_SCALE := 0.55
## His left hand, in character space. The beer stays in his right.
const HAND := Vector2(-37.0, -104.0)
const REST_ANGLE := -0.2
const WINDUP_ANGLE := 0.6
const STRIKE_ANGLE := -1.2
const BANG_VOLUME_DB := -10.0
const WRENCH_Z := 10
## How far he leans back to drink, and how often he does it when idle.
const SIP_LEAN := 0.14
const SIP_INTERVAL := Vector2(4.0, 8.0)
const SIP_VOLUME_DB := -12.0
## A twitch fit: this many jolts, each up to this far and this tipped.
const TWITCH_JOLTS_PER_SECOND := 18.0
const TWITCH_PIXELS := 5.0
const TWITCH_ANGLE := 0.09

## Which way he's turned. The wrench is in his left hand, so facing left
## puts it on his right-hand side of the screen.
@export var facing_right: bool = false
## Also the name quests use as their `giver`.
@export var display_name: String = "Grandpa"
## Drive further than this and the dialog closes itself.
@export var dialog_range: float = 300.0

@export_group("Lines")
@export var idle_line: String = "Leave me alone, I'm drinkin'."
## Said when a quest has no reminder_line / turn_in_line of its own.
@export var default_reminder_line: String = "Well? Get to it!"
@export var default_turn_in_line: String = "About time."

var actor: CutsceneActor

var _wrench: Node2D
var _next_sip: float = 2.0
var _swing: Tween
var _move: Tween
var _dialog: CharacterDialog
## The car that opened the dialog, so it closes when that car drives off.
var _talker: Node2D = null

func _ready() -> void:
	actor = CutsceneActor.new()
	actor.setup(CHARACTER, ACTOR_SCALE)
	add_child(actor)
	actor.face(facing_right)
	_wrench = WRENCH.instantiate()
	_wrench.position = HAND
	_wrench.rotation = REST_ANGLE
	# Character parts draw on z 0-6 by slot; the wrench goes in front of them all.
	_wrench.z_index = WRENCH_Z
	_wrench.visible = false
	actor.attach(_wrench)
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -BODY_SIZE.y * 0.5)
	add_child(collision)
	_dialog = DIALOG_SCENE.instantiate()
	add_child(_dialog)

func _process(delta: float) -> void:
	if _dialog.is_open():
		if not is_instance_valid(_talker) \
				or global_position.distance_to(_talker.global_position) > dialog_range:
			_dialog.close()
		return
	if Cutscenes.is_active():
		return
	_next_sip -= delta
	if _next_sip <= 0.0:
		_next_sip = randf_range(SIP_INTERVAL.x, SIP_INTERVAL.y)
		sip()

## PlayerCar's prompt: says so when there's a quest to hand in.
func get_interact_prompt() -> String:
	var quest := _ready_quest()
	if quest != null:
		return "%s: Press E to hand in \"%s\"" % [display_name, quest.title]
	return "%s: Press E to talk" % display_name

## He sits right by the garage door: talking to him wins over walking in.
func get_interact_priority() -> int:
	return 1

## Called by PlayerCar on E or a click.
func interact(talker: Node = null) -> void:
	if _dialog.is_open():
		return
	_talker = talker as Node2D
	_dialog.open(display_name, CHARACTER)
	var quest := _ready_quest()
	if quest != null:
		var reward := Quests.turn_in(quest.id)
		_dialog.say(PlayerProfile.fill(_line_or(quest.turn_in_line, default_turn_in_line)))
		var note := ""
		if Quests.hands_over_scrap(quest):
			Sfx.play(&"scrap_pickup", -6.0, 0.0)
			note = "-%d scrap   " % quest.scrap_goal
		if reward > 0:
			Sfx.play(&"cash_register", -4.0, 0.0)
			note += "+$%d   You have $%d" % [reward, Inventory.money]
		_dialog.set_note(note)
	elif not Quests.quests_from(display_name).is_empty():
		var current := Quests.quests_from(display_name)[0]
		_dialog.say(PlayerProfile.fill(_line_or(current.reminder_line, default_reminder_line)))
	else:
		_dialog.say(PlayerProfile.fill(idle_line))
	_dialog.set_options([CharacterDialog.Option.new("Walk away", _dialog.close)])

## The oldest of his quests that's ready to hand in, if any.
func _ready_quest() -> QuestData:
	for quest in Quests.quests_from(display_name):
		if Quests.is_ready(quest.id):
			return quest
	return null

static func _line_or(line: String, fallback: String) -> String:
	return line if not line.strip_edges().is_empty() else fallback

func show_wrench(visible_now: bool) -> void:
	_wrench.visible = visible_now

## Leans back in the chair for a slurp of beer, and settles again.
func sip(volume_db: float = SIP_VOLUME_DB) -> Tween:
	var lean := SIP_LEAN * (1.0 if facing_right else -1.0)
	_restart_move()
	_move.tween_property(actor, "rotation", -lean, 0.35).set_ease(Tween.EASE_OUT)
	_move.tween_callback(func() -> void:
		Sfx.play_at(&"beer_sip", global_position, volume_db, 0.08))
	_move.tween_interval(0.55)
	_move.tween_property(actor, "rotation", 0.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	return _move

## A fit of jerky little jolts for `seconds`, snapping back to rest after.
func twitch(seconds: float, volume_db: float = -6.0) -> Tween:
	_restart_move()
	Sfx.play_at(&"grandpa_twitch", global_position, volume_db, 0.05)
	var jolts := maxi(1, int(seconds * TWITCH_JOLTS_PER_SECOND))
	var step := seconds / jolts
	for i in jolts:
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.3)) * TWITCH_PIXELS
		_move.tween_property(actor, "position", offset, step)
		_move.parallel().tween_property(actor, "rotation", randf_range(-1.0, 1.0) * TWITCH_ANGLE, step)
	_move.tween_property(actor, "position", Vector2.ZERO, 0.08)
	_move.parallel().tween_property(actor, "rotation", 0.0, 0.08)
	return _move

## Winds the wrench back, slams it down with a clang, and lets it settle.
func bang(volume_db: float = BANG_VOLUME_DB) -> Tween:
	_wrench.visible = true
	if _swing != null:
		_swing.kill()
	_swing = create_tween().set_trans(Tween.TRANS_QUAD)
	_swing.tween_property(_wrench, "rotation", WINDUP_ANGLE, 0.14).set_ease(Tween.EASE_OUT)
	_swing.tween_property(_wrench, "rotation", STRIKE_ANGLE, 0.07).set_ease(Tween.EASE_IN)
	_swing.tween_callback(func() -> void:
		Sfx.play_at(&"wrench_clunk", global_position, volume_db, 0.12))
	_swing.tween_property(_wrench, "rotation", REST_ANGLE, 0.25).set_ease(Tween.EASE_OUT)
	return _swing

func _restart_move() -> void:
	if _move != null:
		_move.kill()
	actor.position = Vector2.ZERO
	actor.rotation = 0.0
	_move = create_tween().set_trans(Tween.TRANS_SINE)
