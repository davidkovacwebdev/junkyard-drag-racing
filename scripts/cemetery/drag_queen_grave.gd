@tool
class_name DragQueenGrave
extends StaticBody2D
## The Drag Queen's resting place, tucked away in the back of the cemetery:
## a stone statue of her on a plinth (big bouffant, one arm thrown up, a
## gold tiara), a trans flag flying beside it and two mourners (her parents,
## each holding a little trans flag) keeping her company. Origin at the foot of the plinth so it Y-sorts against the car.
##
## While "Pay Your Respects" is on, driving up and pressing E plays the
## scene where the player leaves Grandpa's wheel here
## (DragQueenGraveCutscene). Once that's done the wheel stays leaning on
## the grave for good.

const QUEST_ID := &"pay_respects"
const GRAVE_SCENE_PATH := "res://cutscenes/drag_queen_grave.tres"
const WHEEL := preload("res://scenes/characters/props/grandpas_wheel.tscn")
const DARLENE := preload("res://characters/mourner_darlene.tres")
const GUS := preload("res://characters/mourner_gus.tres")
const TRANS_FLAG := preload("res://scenes/characters/props/trans_hand_flag.tscn")

const STONE := GraveyardProp.STONE
const STONE_SHADE := GraveyardProp.STONE_SHADE
const MOUND := GraveyardProp.MOUND
const TIARA := UiPalette.ACCENT_YELLOW

## Where the wheel leans against the grave, and how big and tipped it is.
const WHEEL_SPOT := Vector2(-34.0, 14.0)
const WHEEL_SCALE := 0.7
const WHEEL_TILT := 0.35
## Relative to the grave: the flag, the mourners, and where the player
## stands to pay respects.
const FLAG_SPOT := Vector2(104.0, -6.0)
const FLAG_POLE_HEIGHT := 250.0
const MOURNER_SPOTS: Array[Vector2] = [Vector2(-140.0, 18.0), Vector2(-198.0, -4.0)]
const PLAYER_SPOT := Vector2(-60.0, 90.0)
## Everything in `_draw()` is authored at 1x and drawn this much bigger, so
## she towers over the people standing around her.
const STATUE_SCALE := 1.5

@export var display_name: String = "Drag Queen's Grave"

var mourners: Array[CemeteryMourner] = []
var flag: PrideFlag

var _wheel: Node2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(108.0, 34.0) * STATUE_SCALE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -6.0) * STATUE_SCALE
	add_child(collision)
	_wheel = WHEEL.instantiate()
	_wheel.position = WHEEL_SPOT
	_wheel.scale = Vector2.ONE * WHEEL_SCALE
	_wheel.rotation = WHEEL_TILT
	add_child(_wheel)
	show_wheel(Quests.is_ready(QUEST_ID) or Quests.is_complete(QUEST_ID))
	_place_company.call_deferred()

## The flag and the mourners stand on their own in the Y-sort, next to it.
func _place_company() -> void:
	var parent := get_parent()
	flag = PrideFlag.new()
	flag.position = position + FLAG_SPOT
	flag.pole_height = FLAG_POLE_HEIGHT
	parent.add_child(flag)
	for i in MOURNER_SPOTS.size():
		var mourner := CemeteryMourner.new()
		mourner.character_data = [DARLENE, GUS][i]
		mourner.facing_right = true
		mourner.held_prop = TRANS_FLAG
		mourner.position = position + MOURNER_SPOTS[i]
		parent.add_child(mourner)
		mourners.append(mourner)

func show_wheel(shown: bool) -> void:
	if _wheel != null:
		_wheel.visible = shown

func player_spot() -> Vector2:
	return global_position + PLAYER_SPOT

func wheel_spot() -> Vector2:
	return global_position + WHEEL_SPOT

func _can_leave_wheel() -> bool:
	return Quests.has_quest(QUEST_ID) and not Quests.is_ready(QUEST_ID)

func get_interact_prompt() -> String:
	if _can_leave_wheel():
		return "%s: Press E to leave Grandpa's wheel" % display_name
	return "Here lies the Drag Queen. Gone, never forgotten."

## Called by PlayerCar on E.
func interact(_talker: Node = null) -> void:
	if not _can_leave_wheel() or Cutscenes.is_active():
		return
	var scene := ResourceLoader.load(GRAVE_SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as DragQueenGraveCutscene
	if scene == null:
		return
	scene.grave = self
	await Cutscenes.play(scene)
	show_wheel(true)
	Quests.goal_met(QUEST_ID)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * STATUE_SCALE)
	draw_colored_polygon(FlatProps.octagon(Vector2(12.0, 2.0), 84.0, 16.0), UiPalette.SHADOW)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, 18.0), 46.0, 11.0), MOUND)
	# The plinth.
	draw_rect(Rect2(-50.0, -46.0, 100.0, 46.0), STONE)
	draw_rect(Rect2(34.0, -46.0, 16.0, 46.0), STONE_SHADE)
	# Her: a mermaid gown up to the shoulders, one arm thrown up to the crowd.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-36.0, -46.0), Vector2(-16.0, -84.0), Vector2(-13.0, -122.0), Vector2(-21.0, -150.0),
		Vector2(20.0, -151.0), Vector2(14.0, -122.0), Vector2(17.0, -84.0), Vector2(35.0, -46.0),
	]), STONE)
	draw_colored_polygon(FlatProps.sliver(Vector2(15.0, -146.0), Vector2(42.0, -198.0), 10.0), STONE)
	# The bouffant, then the face in front of it.
	draw_colored_polygon(FlatProps.octagon(Vector2(-1.0, -184.0), 27.0, 25.0), STONE_SHADE)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -164.0), 12.0, 14.0), STONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15.0, -203.0), Vector2(-11.0, -217.0), Vector2(-5.0, -208.0), Vector2(0.0, -222.0),
		Vector2(5.0, -208.0), Vector2(11.0, -217.0), Vector2(15.0, -203.0),
	]), TIARA)
