class_name GrandpaNpc
extends StaticBody2D
## Grandpa, parked in his wheelchair next to the player's car. Left alone he
## leans back for a sip of beer every few seconds.
##
## Drive up and press E to talk (the standard CharacterDialog). He's a quest
## giver, in this order of business:
##   1. a quest of his is ready to hand in: talking finishes it and pays up,
##      and if that unlocked another of his, he offers it right away;
##   2. he has a quest available (his head is on the minimap): talking plays
##      its start cutscene, which gives it;
##   3. one of his quests is in progress: he nags;
##   4. otherwise he wants to be left alone.
## Duck-typed for PlayerCar like the scrap dealer: a `display_name`,
## `get_interact_prompt()` and `interact()`, on a body the car can bump into.
## In the `quest_giver` group with his `character_data`, which is how the
## minimap finds him and draws his head.
##
## He holds still while a cutscene runs, so the scene can call `sip()`,
## `twitch()`, `bang()`, `sob()`, `hiccup()`, `wink()` and `laugh()` on its
## own beats instead. The bent wrench only comes out for `bang()`, when he
## whacks at his busted wheelchair; `bang(..., true)` swings the straight new
## one the player brought him instead.
##
## `actor` is a plain CutsceneActor, so cutscenes can hand it to
## Cutscenes.subtitle() for the talking squash like any spawned actor.

const CHARACTER := preload("res://characters/grandpa.tres")
const DIALOG_SCENE := preload("res://scenes/ui/character_dialog.tscn")
## The wheelchair's footprint on the ground, which the car bumps into.
const BODY_SIZE := Vector2(80.0, 40.0)
const WRENCH := preload("res://scenes/characters/props/bent_wrench.tscn")
const NEW_WRENCH := preload("res://scenes/characters/props/straight_wrench.tscn")
## Same size as every other character standing in the world.
const ACTOR_SCALE := 0.55
## His left hand, in character space. The beer stays in his right.
const HAND := Vector2(-37.0, -104.0)
## The wrench's swing: back, then down onto the wheelchair's tyre beside him.
const REST_ANGLE := -0.2
const WINDUP_ANGLE := 0.5
const STRIKE_ANGLE := -2.6
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
const GIVER_GROUP := &"quest_giver"
## A crying jag: his shoulders heave this often, this far, and a tear drops
## from under each eye in turn (character space).
const SOB_HEAVES_PER_SECOND := 3.0
const SOB_PIXELS := 4.0
const TEAR_FROM := [Vector2(-12.0, -200.0), Vector2(12.0, -200.0)]
const TEAR_FALL := 46.0
const TEAR_COLOR := Color(0.56, 0.72, 0.84, 1)
const TEAR_Z := 11
## The wink: his left eye's white and pupil hide behind a shut-lid chevron.
const WINK_EYE_NODES := [^"WhiteLeft", ^"PupilLeft"]
const WINK_LID := [Vector2(-19.0, -218.0), Vector2(-10.0, -215.0), Vector2(-1.0, -218.0),
		Vector2(-1.0, -213.0), Vector2(-10.0, -210.0), Vector2(-19.0, -213.0)]
const WINK_LID_COLOR := Color(0.06, 0.06, 0.08, 1)
## A belly laugh: he rocks back this far and his shoulders bounce this often.
const LAUGH_LEAN := 0.12
const LAUGH_BOUNCES_PER_SECOND := 7.0
const LAUGH_PIXELS := 5.0

## Which way he's turned. The wrench is in his left hand, so facing left
## puts it on his right-hand side of the screen.
@export var facing_right: bool = false
## Also the name quests use as their `giver`.
@export var display_name: String = "Grandpa"
## Drive further than this and the dialog closes itself.
@export var dialog_range: float = 300.0

@export_group("Lines")
## Said when he has nothing for the player and his character's Idle Lines
## (characters/grandpa.tres, Dialogue) are empty.
@export var idle_line: String = "Leave me alone, I'm drinkin'."
## Said when a quest has no reminder_line / turn_in_line of its own.
@export var default_reminder_line: String = "Well? Get to it!"
@export var default_turn_in_line: String = "About time."

var actor: CutsceneActor
## What the minimap draws his head from.
var character_data: CharacterData = CHARACTER

var _wrench: Node2D
var _new_wrench: Node2D
var _next_sip: float = 2.0
var _swing: Tween
var _move: Tween
var _dialog: CharacterDialog
## The car that opened the dialog, so it closes when that car drives off.
var _talker: Node2D = null

func _ready() -> void:
	add_to_group(GIVER_GROUP)
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
	_new_wrench = NEW_WRENCH.instantiate()
	_new_wrench.position = HAND
	_new_wrench.rotation = REST_ANGLE
	_new_wrench.z_index = WRENCH_Z
	_new_wrench.visible = false
	actor.attach(_new_wrench)
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
	if not Quests.available_from(display_name).is_empty():
		return "%s: Press E to talk (new quest)" % display_name
	return "%s: Press E to talk" % display_name

## He sits right by the garage door: talking to him wins over walking in.
func get_interact_priority() -> int:
	return 1

## Called by PlayerCar on E or a click.
func interact(talker: Node = null) -> void:
	if _dialog.is_open():
		return
	_talker = talker as Node2D
	if _ready_quest() == null and not Quests.available_from(display_name).is_empty():
		_start_quest(Quests.available_from(display_name)[0])
		return
	_dialog.open(display_name, CHARACTER)
	var quest := _ready_quest()
	if quest != null:
		var empty_handed := Quests.empty_handed(quest)
		var reward := Quests.turn_in(quest.id)
		if empty_handed:
			_dialog.say(Quests.fill(quest, quest.empty_handed_line))
			_weep()
		else:
			_dialog.say(Quests.fill(quest, _line_or(quest.turn_in_line, default_turn_in_line)))
		var note := ""
		if not quest.turn_in_sound.is_empty():
			Sfx.play_at(quest.turn_in_sound, global_position, -4.0, 0.05)
		if Quests.hands_over_scrap(quest):
			Sfx.play(&"scrap_pickup", -6.0, 0.0)
			note = "-%d scrap   " % quest.scrap_goal
		if Quests.hands_over_item(quest):
			note = "-%s   " % quest.item_goal.display_name
		if reward > 0:
			Sfx.play(&"cash_register", -4.0, 0.0)
			note += "+$%d   You have $%d   " % [reward, Inventory.money]
		var part := Quests.reward_part_data(quest)
		if part != null:
			Sfx.play(&"part_pickup", -6.0, 0.0)
			note += "+%s (spare parts)" % part.display_name
		_dialog.set_note(note)
	elif not Quests.quests_from(display_name).is_empty():
		var current := Quests.quests_from(display_name)[0]
		_dialog.say(Quests.fill(current, _line_or(current.reminder_line, default_reminder_line)))
	else:
		_dialog.say(PlayerProfile.fill(CHARACTER.idle_line(idle_line)))
	var options := [CharacterDialog.Option.new("Walk away", _dialog.close)]
	if not Quests.available_from(display_name).is_empty():
		options.push_front(CharacterDialog.Option.new("Need anything else?", _on_anything_else))
	_dialog.set_options(options)

func _on_anything_else() -> void:
	var next := Quests.available_from(display_name)
	_dialog.close()
	if not next.is_empty():
		_start_quest(next[0])

## Takes an available quest: plays its start cutscene (which gives it), or
## just gives it when it has none.
func _start_quest(quest: QuestData) -> void:
	var scene: Cutscene = null
	if not quest.start_cutscene.is_empty():
		scene = ResourceLoader.load(quest.start_cutscene, "", ResourceLoader.CACHE_MODE_REPLACE) as Cutscene
	if scene == null:
		Quests.give(quest)
		return
	if "grandpa" in scene:
		scene.set("grandpa", self)
	if scene.gives_quest == null:
		scene.gives_quest = quest
	Cutscenes.play(scene)

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
	_new_wrench.visible = false

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
## `new_wrench` swings the straight one instead of the bent one.
func bang(volume_db: float = BANG_VOLUME_DB, new_wrench: bool = false) -> Tween:
	var wrench := _new_wrench if new_wrench else _wrench
	_wrench.visible = not new_wrench
	_new_wrench.visible = new_wrench
	if _swing != null:
		_swing.kill()
	_swing = create_tween().set_trans(Tween.TRANS_QUAD)
	_swing.tween_property(wrench, "rotation", WINDUP_ANGLE, 0.14).set_ease(Tween.EASE_OUT)
	_swing.tween_property(wrench, "rotation", STRIKE_ANGLE, 0.07).set_ease(Tween.EASE_IN)
	_swing.tween_callback(func() -> void:
		Sfx.play_at(&"wrench_clunk", global_position, volume_db, 0.12))
	# Rests on the tyre a beat, so the hit reads before it lifts.
	_swing.tween_interval(0.12)
	_swing.tween_property(wrench, "rotation", REST_ANGLE, 0.25).set_ease(Tween.EASE_OUT)
	return _swing

## A drunken crying jag for `seconds`: his shoulders heave, he blubbers,
## and tears roll off his cheeks.
func sob(seconds: float, volume_db: float = -6.0) -> Tween:
	_restart_move()
	Sfx.play_at(&"grandpa_sob", global_position, volume_db, 0.06)
	var heaves := maxi(1, int(seconds * SOB_HEAVES_PER_SECOND))
	var step := seconds / heaves * 0.5
	for i in heaves:
		_move.tween_property(actor, "position:y", SOB_PIXELS, step)
		_move.tween_property(actor, "position:y", 0.0, step)
		if i % 2 == 0:
			_move.parallel().tween_callback(_drop_tear.bind(TEAR_FROM[(i / 2) % TEAR_FROM.size()]))
	return _move

## Really bawling: a long sob, a hiccup, then another, louder than in the
## crane scene.
func _weep() -> void:
	var first := sob(2.0, -3.0)
	await first.finished
	if not is_instance_valid(self) or Cutscenes.is_active():
		return
	await hiccup(-4.0).finished
	sob(2.4, -2.0)

## Teary-eyed but holding it together: a tear rolls from each eye in turn,
## `count` in all, no sobbing.
func tear_up(count: int = 2) -> void:
	for i in count:
		_drop_tear(TEAR_FROM[i % TEAR_FROM.size()])
		await get_tree().create_timer(0.45).timeout
		if not is_instance_valid(self):
			return

## A belly laugh for `seconds`: he rocks back in the chair, shoulders
## bouncing, and settles again. `sound` is `grandpa_laugh` or the wheezier
## `grandpa_cackle`; with `tears`, he's laughing so hard they roll.
func laugh(seconds: float, volume_db: float = -4.0, sound: StringName = &"grandpa_laugh",
		tears: bool = false) -> Tween:
	_restart_move()
	Sfx.play_at(sound, global_position, volume_db, 0.04)
	var lean := LAUGH_LEAN * (1.0 if facing_right else -1.0)
	_move.tween_property(actor, "rotation", -lean, 0.18).set_ease(Tween.EASE_OUT)
	var bounces := maxi(1, int(seconds * LAUGH_BOUNCES_PER_SECOND))
	var step := seconds / bounces * 0.5
	for i in bounces:
		_move.tween_property(actor, "position:y", -LAUGH_PIXELS, step)
		_move.tween_property(actor, "position:y", 0.0, step)
		if tears and i % 3 == 0:
			_move.parallel().tween_callback(_drop_tear.bind(TEAR_FROM[(i / 3) % TEAR_FROM.size()]))
	_move.tween_property(actor, "rotation", 0.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	return _move

## Wheels himself (the drawn chair and all; his body stays put) `offset`
## away from his spot, or back with Vector2.ZERO, squeaking as he goes.
## Back home he turns the usual way again (see `face_wrench_toward()`).
func roll_to(offset: Vector2, seconds: float = 0.8) -> Tween:
	if _move != null:
		_move.kill()
	actor.rotation = 0.0
	Sfx.play_at(&"wheelchair_squeak", global_position + actor.position, -6.0, 0.08)
	_move = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move.tween_property(actor, "position", offset, seconds)
	if offset == Vector2.ZERO:
		_move.tween_callback(actor.face.bind(facing_right))
	return _move

## Turns so the wrench hand (and so `bang()`'s strike) is on the side of
## `world_point`. The wrench is in his left hand: facing right puts it on
## the left of the screen.
func face_wrench_toward(world_point: Vector2) -> void:
	actor.face(world_point.x < actor.global_position.x)

## A drunk "hic!": a little jump in the chair.
func hiccup(volume_db: float = -6.0) -> Tween:
	_restart_move()
	Sfx.play_at(&"grandpa_hiccup", global_position, volume_db, 0.08)
	_move.tween_property(actor, "position:y", -7.0, 0.06).set_ease(Tween.EASE_OUT)
	_move.tween_property(actor, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN)
	return _move

## Shuts one eye for a beat, with a tip of the head: "I know a guy".
func wink(volume_db: float = -8.0) -> Tween:
	var eyes := actor.find_child("EyesPart", true, false) as Node2D
	var hidden: Array[Node2D] = []
	var lid: Polygon2D = null
	if eyes != null:
		for path in WINK_EYE_NODES:
			var part := eyes.get_node_or_null(path) as Node2D
			if part != null and part.visible:
				part.visible = false
				hidden.append(part)
		lid = Polygon2D.new()
		lid.polygon = PackedVector2Array(WINK_LID)
		lid.color = WINK_LID_COLOR
		eyes.add_child(lid)
		# Under the brow, like the eye it stands in for.
		eyes.move_child(lid, 0)
	Sfx.play_at(&"wink_ting", global_position, volume_db, 0.0)
	_restart_move()
	var tip := 0.06 * (1.0 if facing_right else -1.0)
	_move.tween_property(actor, "rotation", tip, 0.12).set_ease(Tween.EASE_OUT)
	_move.tween_interval(0.6)
	_move.tween_property(actor, "rotation", 0.0, 0.2).set_ease(Tween.EASE_IN_OUT)
	_move.tween_callback(func() -> void:
		for part in hidden:
			if is_instance_valid(part):
				part.visible = true
		if is_instance_valid(lid):
			lid.queue_free())
	return _move

## One fat teardrop that rolls down from under an eye and is gone.
func _drop_tear(from: Vector2) -> void:
	var tear := Polygon2D.new()
	tear.polygon = PackedVector2Array([Vector2(0.0, -10.0), Vector2(6.0, 1.0),
			Vector2(4.0, 7.0), Vector2(-4.0, 7.0), Vector2(-6.0, 1.0)])
	tear.color = TEAR_COLOR
	tear.position = from
	tear.z_index = TEAR_Z
	actor.attach(tear)
	var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(tear, "position:y", from.y + TEAR_FALL, 0.5)
	fall.parallel().tween_property(tear, "modulate:a", 0.0, 0.2).set_delay(0.3)
	fall.tween_callback(tear.queue_free)

func _restart_move() -> void:
	if _move != null:
		_move.kill()
	actor.position = Vector2.ZERO
	actor.rotation = 0.0
	_move = create_tween().set_trans(Tween.TRANS_SINE)
