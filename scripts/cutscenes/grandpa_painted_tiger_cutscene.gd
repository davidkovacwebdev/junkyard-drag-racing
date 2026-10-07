class_name GrandpaPaintedTigerCutscene
extends Cutscene
## Handing in "Fenced In": the player comes back with a piece of the farm's
## fence. Tiger is standing next to Grandpa, painted (badly) orange and
## black like a tiger, an empty beer bottle under its belly, munching the
## carrots. Grandpa just says "WHAT". The player chucks the fence at him
## (`axe_whoosh`, then a `wood_clonk` off his head) and walks off without a
## word. The quest's `turn_in_cutscene`; GrandpaNpc finishes the quest once
## it's over, and Tiger stays painted.
##
## The words live in res://cutscenes/grandpa_painted_tiger.tres; edit them
## in the inspector.

const ID := &"grandpa_painted_tiger"
const GRANDPA := preload("res://characters/grandpa.tres")
const FENCE := preload("res://scenes/items/icons/item_fence_piece.tscn")

@export var speaker_name: String = "Grandpa"
@export var what_line: String = "WHAT"

@export_group("Staging")
@export var player_offset := Vector2(110.0, -40.0)
## First a close look at Tiger, then the camera pulls back to the three.
@export var tiger_zoom: float = 2.4
@export var wide_zoom: float = 1.7
@export var camera_lift: float = 70.0
## How many carrot crunches the close-up lingers on.
@export var crunches: int = 3
## The throw: from the player's hands (relative to them) to Grandpa's head
## (relative to him), how high it arcs, how long it flies and how big it is.
@export var throw_from := Vector2(-20.0, -110.0)
@export var throw_to := Vector2(0.0, -150.0)
@export var throw_arc: float = 70.0
@export var throw_seconds: float = 0.45
@export var fence_scale: float = 0.8
## Where it ends up after bouncing off him, relative to him: in his lap.
@export var lap_offset := Vector2(10.0, -70.0)
## How far the player walks off, and how fast.
@export var leave_distance: float = 560.0
@export var leave_speed: float = 150.0

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var tiger := grandpa.tiger
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + tiger.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	tiger.visible = true
	tiger.set_painted(true)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(tiger.global_position + Vector2(0.0, -40.0), tiger_zoom)
	await Cutscenes.fade_in(0.8)
	for i in crunches:
		Cutscenes.sound(&"carrot_crunch", -4.0, tiger.global_position)
		await Cutscenes.wait(0.7)
	await Cutscenes.camera_to(middle, wide_zoom, 1.2)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)
	await Cutscenes.wait(0.6)
	if not Cutscenes.is_skipping():
		grandpa.widen_eyes(2.0)
		Cutscenes.shake(5.0, 0.3)
	await Cutscenes.subtitle(speaker_name, GRANDPA, what_line, grandpa.actor)
	await Cutscenes.wait(0.5)
	await _throw_fence(player)
	await Cutscenes.wait(0.6)
	if player != null:
		Cutscenes.face(player, true)
		await Cutscenes.wait(0.3)
		await Cutscenes.walk(player, player.global_position + Vector2(leave_distance, 0.0), leave_speed)
	await Cutscenes.wait(0.4)

## The fence piece flies out of the player's hands in a spinning arc, bonks
## Grandpa on the head and drops into his lap, where it sits till the end.
func _throw_fence(player: CutsceneActor) -> void:
	if Cutscenes.is_skipping():
		return
	var from := (player.global_position if player != null else grandpa.global_position + player_offset) + throw_from
	var to := grandpa.global_position + throw_to
	var fence := FENCE.instantiate() as Node2D
	fence.scale = Vector2.ONE * fence_scale
	fence.z_index = 10
	grandpa.get_parent().add_child(fence)
	fence.global_position = from
	Cutscenes.finished.connect(fence.queue_free, CONNECT_ONE_SHOT)
	Cutscenes.sound(&"axe_whoosh", -4.0)
	var flight := fence.create_tween()
	flight.tween_method(func(t: float) -> void:
		fence.global_position = from.lerp(to, t) + Vector2(0.0, -throw_arc * sin(PI * t))
		fence.rotation = -TAU * 1.5 * t, 0.0, 1.0, throw_seconds)
	await Cutscenes.play_tween(flight)
	Cutscenes.sound(&"wood_clonk", -1.0)
	Cutscenes.shake(7.0, 0.3)
	grandpa.twitch(0.6, -4.0)
	var drop := fence.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(fence, "global_position", grandpa.global_position + lap_offset, 0.3)
	drop.parallel().tween_property(fence, "rotation", 0.25, 0.3)
	await Cutscenes.play_tween(drop)
