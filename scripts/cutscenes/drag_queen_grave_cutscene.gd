class_name DragQueenGraveCutscene
extends Cutscene
## "Pay Your Respects", at the Drag Queen's grave in the cemetery: the player
## carries Grandpa's wheel over and leaves it by her statue, and everyone
## stands there in silence for a few seconds. Then the player asks the two
## mourners whether she really was that good a driver, they look at each
## other, and one says she didn't even have a driver's license. The player
## turns away and whispers that Grandpa doesn't know what a drag queen is.
## Plays when the player presses E at the grave (DragQueenGrave), which
## meets the quest's goal once it's over so the player can go back to Grandpa.
##
## The words live in res://cutscenes/drag_queen_grave.tres; edit them in the
## inspector.

const ID := &"drag_queen_grave"
const WHEEL := preload("res://scenes/characters/props/grandpas_wheel.tscn")

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var question_line: String = "Was she really that good of a driver?"
## Said by the first mourner, after the two of them trade a look.
@export var answer_line: String = "She didn't even have a driver's license..."
@export var whisper_line: String = "I don't think my grandpa knows what a drag queen is."

@export_group("Staging")
@export var zoom: float = 1.5
@export var whisper_zoom: float = 2.6
## The moment of silence, after the bell.
@export var silence_seconds: float = 3.5
## Where the player carries the wheel, in their character space.
@export var carry_spot := Vector2(34.0, -90.0)
## Where they stand to set it down, relative to where it ends up.
@export var set_down_offset := Vector2(-46.0, 34.0)

## Set by DragQueenGrave before playing.
var grave: DragQueenGrave

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grave):
		return
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var start := car.global_position if car != null else grave.player_spot() + Vector2(-160.0, 60.0)
	# Low enough for everyone's feet, high enough for her tiara.
	var middle := grave.global_position + Vector2(-80.0, -120.0)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	var wheel: Node2D = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, start + Vector2(0.0, -10.0),
				start.x < grave.global_position.x)
		wheel = WHEEL.instantiate()
		wheel.position = carry_spot
		wheel.z_index = GrandpaNpc.WRENCH_Z
		player.attach(wheel)
	Cutscenes.cut_to((start + middle) * 0.5, zoom)
	await Cutscenes.fade_in(0.8)

	if player != null:
		Cutscenes.camera_follow(player)
		await Cutscenes.walk(player, grave.wheel_spot() + set_down_offset, 130.0)
		Cutscenes.face(player, true)
		await Cutscenes.wait(0.3)
	if is_instance_valid(wheel):
		wheel.queue_free()
	grave.show_wheel(true)
	Cutscenes.sound(&"wood_clonk", -4.0, grave.wheel_spot())
	await Cutscenes.camera_to(middle, zoom, 0.8)
	if player != null:
		await Cutscenes.walk(player, grave.player_spot(), 90.0)
		Cutscenes.face(player, grave.global_position.x > player.global_position.x)

	# A moment of silence.
	Cutscenes.sound(&"funeral_bell", -6.0, grave)
	await Cutscenes.wait(silence_seconds)

	var mourners := grave.mourners
	if player != null and not mourners.is_empty():
		Cutscenes.face(player, mourners[0].global_position.x > player.global_position.x)
	await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character, question_line, player)
	# The mourners look at each other, baffled.
	if mourners.size() >= 2:
		mourners[0].face(mourners[1].global_position.x > mourners[0].global_position.x)
		mourners[1].face(mourners[0].global_position.x > mourners[1].global_position.x)
		await Cutscenes.wait(0.9)
		mourners[0].face(player == null or player.global_position.x > mourners[0].global_position.x)
	if not mourners.is_empty():
		await Cutscenes.subtitle(mourners[0].character_data.display_name, mourners[0].character_data,
				answer_line, mourners[0].actor)
	await Cutscenes.wait(0.6)

	if player != null:
		Cutscenes.face(player, true)
		await Cutscenes.camera_to(player.global_position + Vector2(0.0, -70.0), whisper_zoom, 0.6)
	await Cutscenes.subtitle(PlayerProfile.display_name() + " (whispering)", PlayerProfile.character,
			whisper_line, player)
	await Cutscenes.wait(0.6)
	for mourner in mourners:
		mourner.face(true)
