class_name GrandpaDragQueenCutscene
extends Cutscene
## After "Beer Run": Grandpa is crying again. Today's the anniversary of the
## tragic death of the Drag Queen, the best drag racer this town has ever
## seen. The player has never heard of her (and finds the name a bit weird),
## so Grandpa blows up and makes them kiss her flag, the little trans flag
## on his wheelchair's pole. Then he remembers they have to pay their respects and holds
## up the "beautiful" wooden steering wheel he made her. Unlocked by "Beer
## Run"; plays when the player talks to him while it's available
## (GrandpaNpc), and gives "Pay Your Respects".
##
## The words live in res://cutscenes/grandpa_drag_queen.tres; edit them in
## the inspector. The beats:
##   - he's mid-sob as the scene fades in; the player walks up and asks the
##     `ask_line`, and he blubbers the `sob_lines`
##   - the player says the `doubt_line`; he twitches with rage, shouts the
##     `rage_lines`, then the camera swings to the flag for the `kiss_lines`
##   - the player walks to the flag and kisses it (a smooch and a heart)
##   - calmer, he holds up his wheel for the `wheel_lines`

const ID := &"grandpa_drag_queen"
const GRANDPA := preload("res://characters/grandpa.tres")
const WHEEL := preload("res://scenes/characters/props/grandpas_wheel.tscn")
const HEART_COLOR := Color(0.92, 0.42, 0.55)

@export var speaker_name: String = "Grandpa"
## What the player asks as they walk up. These defaults are the scene as
## written; edits in the inspector on the .tres override them.
@export var ask_line: String = "What's wrong, Grandpa? ...Again?"
## Blubbered between sobs.
@export_multiline var sob_lines: PackedStringArray = [
	"T-t-today's the anniversary... of the tragic death of the Drag Queen. *sniff*",
	"The b-best drag racer this town has ever seen...",
]
@export var doubt_line: String = "How come I've never heard of her? Also, a pretty weird name."
## Shouted, shaking with rage.
@export_multiline var rage_lines: PackedStringArray = [
	"You disrespectful piece of pan full of shit.",
]
## Said with the camera on the flag; the last one is screamed.
@export_multiline var kiss_lines: PackedStringArray = [
	"You better kiss her flag.",
	"KISS IT!",
]
## Calmed down, holding up the wheel.
@export_multiline var wheel_lines: PackedStringArray = [
	"This reminds me, we gotta pay our respects.",
	"I made this beautiful wooden steering wheel.",
	"I want you to leave it next to her resting place...",
]

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
## Where the player stands to kiss the flag: this far past it, sideways,
## and this far in front of the wheelchair.
@export var kiss_offset := Vector2(30.0, 8.0)
@export var zoom: float = 1.9
@export var flag_zoom: float = 2.2
@export var wheel_zoom: float = 2.8
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
@export var sob_seconds: float = 1.3
## Where he holds the wheel up, in his character space, and how big.
@export var wheel_hold := Vector2(-10.0, -285.0)
@export var wheel_scale: float = 1.4

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID
	# The default, so the quest survives even if the .tres doesn't list it.
	gives_quest = preload("res://quests/pay_respects.tres")

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	_sob()
	await Cutscenes.fade_in(1.0)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)
	await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character, ask_line, player)
	await _sob()
	for line in sob_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
		await _sob()

	await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character, doubt_line, player)
	await _rage()
	for line in rage_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)

	await Cutscenes.camera_to(grandpa.trans_flag_position(), flag_zoom, 0.8)
	for i in kiss_lines.size():
		if i == kiss_lines.size() - 1:
			Cutscenes.shake(14.0, 0.5)
			Cutscenes.sound(&"grandpa_twitch", -2.0, grandpa)
		await Cutscenes.subtitle(speaker_name, GRANDPA, kiss_lines[i], grandpa.actor)

	if player != null:
		await _kiss(player)
		await Cutscenes.camera_to(middle, zoom, 0.8)
		await Cutscenes.walk(player, player_spot, 140.0)
		Cutscenes.face(player, false)

	var wheel: Node2D = null
	for i in wheel_lines.size():
		# After the first line the wheel comes out, and the camera moves in
		# for a good look at his handiwork.
		if i == 1:
			wheel = _hold_up_wheel()
			await Cutscenes.camera_to(wheel.global_position, wheel_zoom, 0.7)
		await Cutscenes.subtitle(speaker_name, GRANDPA, wheel_lines[i], grandpa.actor)
	if not Cutscenes.is_skipping():
		grandpa.tear_up(2)
	await Cutscenes.wait(0.8)
	if is_instance_valid(wheel):
		wheel.queue_free()

func _sob() -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.sob(sob_seconds)
	await Cutscenes.wait(sob_seconds)

## Shaking with rage in his chair, the camera rattling along.
func _rage() -> void:
	if Cutscenes.is_skipping():
		return
	grandpa.twitch(0.8, -3.0)
	Cutscenes.shake(8.0, 0.8)
	await Cutscenes.wait(0.9)

## The player trudges over, stretches up on their toes and plants a big one
## on the flag: a smooch and a little heart floating off. They go round to
## the far side of the pole from Grandpa, in front of the wheelchair.
func _kiss(player: CutsceneActor) -> void:
	var flag := grandpa.trans_flag_position()
	var side := signf(flag.x - grandpa.global_position.x)
	if side == 0.0:
		side = 1.0
	var spot := Vector2(flag.x + side * kiss_offset.x, grandpa.global_position.y + kiss_offset.y)
	await Cutscenes.walk(player, spot, 110.0)
	Cutscenes.face(player, flag.x > spot.x)
	await Cutscenes.wait(0.4)
	if Cutscenes.is_skipping():
		return
	await Cutscenes.hop(player, 10.0)
	Cutscenes.sound(&"flag_kiss", -2.0, player)
	_pop_heart(flag + Vector2(0.0, -14.0))
	await Cutscenes.wait(0.9)

func _pop_heart(at: Vector2) -> void:
	var heart := Polygon2D.new()
	heart.polygon = PackedVector2Array([Vector2(0.0, 10.0), Vector2(-12.0, -2.0), Vector2(-11.0, -9.0),
			Vector2(-5.0, -12.0), Vector2(0.0, -7.0), Vector2(5.0, -12.0), Vector2(11.0, -9.0), Vector2(12.0, -2.0)])
	heart.color = HEART_COLOR
	heart.z_index = 20
	Cutscenes.get_tree().current_scene.add_child(heart)
	heart.global_position = at
	var tween := heart.create_tween().set_parallel()
	tween.tween_property(heart, "position:y", heart.position.y - 50.0, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.chain().tween_callback(heart.queue_free)

## His wheel pops up in his hand, held high for everyone to admire.
func _hold_up_wheel() -> Node2D:
	var wheel := WHEEL.instantiate() as Node2D
	wheel.position = wheel_hold
	wheel.z_index = GrandpaNpc.WRENCH_Z
	grandpa.actor.attach(wheel)
	if Cutscenes.is_skipping():
		wheel.scale = Vector2.ONE * wheel_scale
		return wheel
	wheel.scale = Vector2.ZERO
	var tween := wheel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(wheel, "scale", Vector2.ONE * wheel_scale, 0.35)
	Cutscenes.sound(&"wood_clonk", -6.0, grandpa)
	return wheel
