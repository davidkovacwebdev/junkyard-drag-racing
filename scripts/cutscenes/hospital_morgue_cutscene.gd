class_name HospitalMorgueCutscene
extends Cutscene
## "Bad News", in the hospital morgue: the player walks in, and Grandpa is on
## the slab under a sheet, flat as a line. The doctor says he was found at
## the junkyard with a crane on top of him. The player cries, thanks him,
## and he says the funeral will be arranged. Played by HospitalMorgue as
## soon as the morgue loads.
##
## The words live in res://cutscenes/hospital_morgue.tres; edit them in the
## inspector.

const ID := &"hospital_morgue"
const DOCTOR := preload("res://characters/doctor.tres")

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var question_line: String = "What happened?"
@export var found_line: String = "He was found at the junkyard. Not sure what he was trying to do..."
@export var crane_line: String = "A crane fell on top of him. We're sorry."
@export var thanks_line: String = "Thanks, doc."
@export var funeral_line: String = "The funeral will be arranged."

@export_group("Staging")
@export var zoom: float = 1.2
@export var table_zoom: float = 1.9
## How long the player stares at the sheet before saying anything.
@export var stare_seconds: float = 1.8
@export var cry_seconds: float = 2.6

## Set by HospitalMorgue before playing.
var morgue: HospitalMorgue

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(morgue):
		return
	var me := PlayerProfile.character
	var name := PlayerProfile.display_name()
	var to_world := func(spot: Vector2) -> Vector2: return morgue.to_global(spot)
	var table_top: Vector2 = morgue.table.global_position + Vector2(0.0, -110.0)

	await Cutscenes.fade_out(0.0)
	var doctor := Cutscenes.spawn_actor(DOCTOR, to_world.call(morgue.doctor_spot), false)
	doctor.reparent(morgue.grounds)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, to_world.call(morgue.door_spot), true)
		player.reparent(morgue.grounds)
	Cutscenes.cut_to(morgue.global_position + Vector2(-120.0, -20.0), zoom)
	await Cutscenes.fade_in(1.0)

	if player != null:
		await Cutscenes.walk(player, to_world.call(morgue.player_spot), 110.0)
	await Cutscenes.camera_to(table_top, table_zoom, 1.2)
	await Cutscenes.wait(stare_seconds)
	await Cutscenes.camera_to((table_top + doctor.global_position) * 0.5 + Vector2(-140.0, -60.0), zoom + 0.2, 0.8)

	await Cutscenes.subtitle(name, me, question_line, player)
	await Cutscenes.subtitle(DOCTOR.display_name, DOCTOR, found_line, doctor)
	await Cutscenes.subtitle(DOCTOR.display_name, DOCTOR, crane_line, doctor)

	if player != null:
		await Cutscenes.camera_to(player.global_position + Vector2(0.0, -130.0), table_zoom, 0.6)
		player.cry(cry_seconds)
		if not Cutscenes.is_skipping():
			# The player's own sob: Grandpa's, pitched up out of his range.
			Sfx.play(&"grandpa_sob", -5.0, 0.0).pitch_scale = 1.35
		await Cutscenes.wait(cry_seconds)
	await Cutscenes.subtitle(name, me, thanks_line, player)
	await Cutscenes.subtitle(DOCTOR.display_name, DOCTOR, funeral_line, doctor)
	await Cutscenes.wait(1.0)
