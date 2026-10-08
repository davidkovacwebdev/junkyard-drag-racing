class_name HospitalMorgue
extends Node2D
## The hospital's morgue, where "Bad News" ends: a tiled floor, a back wall
## with a bank of steel body drawers, and the slab with Grandpa on it
## (MorgueTable). There's nothing to do here but watch: the scene
## (HospitalMorgueCutscene) plays as soon as it loads, finishes the quest,
## and the player is back outside the hospital.
##
## The scene's root, so the room it paints sits behind the Y-sorted
## `Grounds` child (see JunkyardYard). The music stays off in here; the
## strip lights hum instead.

const QUEST_ID := &"hospital_visit"
const SCENE_PATH := "res://cutscenes/hospital_morgue.tres"
const WORLD_SCENE := "res://scenes/world/main.tscn"

const FLOOR := Color(0.6, 0.65, 0.6, 1)
const WALL := Color(0.72, 0.77, 0.73, 1)
const WALL_SHADE := Color(0.58, 0.63, 0.59, 1)
const DRAWERS := Color(0.66, 0.68, 0.7, 1)
const DRAWERS_SHADE := Color(0.5, 0.52, 0.55, 1)
const HANDLE := Color(0.3, 0.31, 0.34, 1)

@export var room_size: Vector2 = Vector2(1500, 900)
## How far down the back wall comes from the top of the room.
@export var wall_height: float = 330.0

## Where people come in, stand and wait, in this node's space.
@export var door_spot := Vector2(-560.0, 330.0)
@export var player_spot := Vector2(-150.0, 120.0)
@export var doctor_spot := Vector2(260.0, -10.0)

@onready var grounds: Node2D = $Grounds
@onready var table: MorgueTable = $Grounds/MorgueTable

func _ready() -> void:
	Music.hush(true, 0.6)
	($LightHum as SustainedSound).set_active(true)
	_play.call_deferred()

func _exit_tree() -> void:
	Music.hush(false)

func _play() -> void:
	# Let the camera settle in first.
	await get_tree().process_frame
	var scene := ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as HospitalMorgueCutscene
	if scene != null:
		scene.morgue = self
		await Cutscenes.play(scene)
	Quests.complete(QUEST_ID)
	SaveSystem.save_game()
	SceneLoader.change_scene(WORLD_SCENE)

func _draw() -> void:
	var half := room_size * 0.5
	draw_rect(Rect2(-half - Vector2(400.0, 400.0), room_size + Vector2(800.0, 800.0)), FLOOR)
	var wall := Rect2(-half.x - 400.0, -half.y - 400.0, room_size.x + 800.0, wall_height + 400.0)
	draw_rect(wall, WALL)
	draw_rect(Rect2(wall.position.x, wall.end.y - 22.0, wall.size.x, 22.0), WALL_SHADE)
	# The body drawers: one steel bank, its shade, and a handle per drawer.
	var bank := Rect2(120.0, -half.y + 30.0, 420.0, wall_height - 70.0)
	draw_rect(bank, DRAWERS)
	draw_rect(Rect2(bank.end.x - 30.0, bank.position.y, 30.0, bank.size.y), DRAWERS_SHADE)
	for i in 3:
		var x := bank.position.x + 40.0 + i * 130.0
		draw_rect(Rect2(x, bank.position.y + bank.size.y * 0.5 - 8.0, 70.0, 16.0), HANDLE)
