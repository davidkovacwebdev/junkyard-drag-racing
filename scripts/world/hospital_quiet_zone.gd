class_name HospitalQuietZone
extends Node2D
## The hush around the hospital, with a "no honking" sign out front
## (no_horn_sign.tscn). Every second the player leans on the horn within
## `radius` counts, and once it adds up to more than `allowed_seconds` the
## police turn up in their garbage truck and fine them (PoliceFineCutscene).
## The count starts over after each fine.

const SCENE_PATH := "res://cutscenes/police_fine.tres"

@export var radius: float = 700.0
@export var allowed_seconds: float = 2.0
## The sign the officers point at.
@export var sign_path: NodePath = ^"../NoHornSign"

## Horn time in the zone since the last fine.
var honked: float = 0.0

var _busy := false

func _process(delta: float) -> void:
	if _busy or Cutscenes.is_active():
		return
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	if car == null or not car.is_honking():
		return
	if car.global_position.distance_to(global_position) > radius:
		return
	honked += delta
	if honked > allowed_seconds:
		_call_police()

func _call_police() -> void:
	_busy = true
	honked = 0.0
	var scene := ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as PoliceFineCutscene
	if scene != null:
		scene.sign_node = get_node_or_null(sign_path) as Node2D
		await Cutscenes.play(scene)
	_busy = false
