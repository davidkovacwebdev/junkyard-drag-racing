class_name PenGarbageTruck
extends Node2D
## The garbage truck that brings the crane pen its junk: backs in from the left
## (beeping), tips its nose up so the load slides out of the loader mouth at
## the back, and drives off again. The same body and CarView rig the city's
## truck uses, moved by tweens like Hank's tow truck (TowTruck).
##
## It only does the driving and the tipping. The junk itself is the heap's:
## `CranePen` hands the truck's mouth to `TrashHeap.dump_from()` while it's
## tipped.

const SCENE := preload("res://scenes/junkyard/pen_garbage_truck.tscn")
const BODY_PATH := "res://scenes/world/garbage_truck/garbage_truck_body.tscn"
const WHEEL_PATH := "res://scenes/parts/wheels/wheel_standard.tscn"
## How far the truck tips back to dump, radians.
const TIP_ANGLE := 0.16
const BEEP_GAP := 1.4

@export var engine_volume_db: float = -14.0

var _facing_right: bool = true
var _last_position: Vector2
var _mouth: Polygon2D = null
var _beep_timer: float = 0.0
var _reversing: bool = false

@onready var _visual: CarView = $Visual as CarView

static func spawn(parent: Node, at: Vector2, facing_right: bool) -> PenGarbageTruck:
	var truck := SCENE.instantiate() as PenGarbageTruck
	parent.add_child(truck)
	truck.global_position = at
	truck.face(facing_right)
	truck._last_position = at
	return truck

func _ready() -> void:
	var model := CarModelData.new()
	model.body = PartDatabase.load_part_data(BODY_PATH) as BodyPartData
	var wheel := PartDatabase.load_part_data(WHEEL_PATH) as WheelPartData
	model.wheels = [wheel, wheel]
	_visual.build_from(model)
	_mouth = _visual.find_child("LoaderMouth", true, false) as Polygon2D
	_setup_engine_sound()
	face(_facing_right)

## Face the cab `right` or left. The art is re-anchored so this node's origin
## is the bottom of the truck's back end: stood on the floor, and the corner it
## tips up about.
func face(right: bool) -> void:
	_facing_right = right
	_visual.scale.x = absf(_visual.scale.x) * (1.0 if right else -1.0)
	_visual.position = Vector2.ZERO
	var bounds := PartScale.measure_bounds(_visual)
	var rear := bounds.position.x if right else bounds.end.x
	_visual.position = -Vector2(rear, bounds.end.y)

## Back up (rear first) to `to`, beeping all the way.
func reverse_to(to: Vector2, seconds: float) -> void:
	_reversing = true
	_beep_timer = 0.0
	await drive_to(to, seconds).finished
	_reversing = false

func drive_to(to: Vector2, seconds: float) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", to, seconds)
	return tween

## Tip the nose up (`tipped`) or back down, pivoting on the rear wheels.
func tip(tipped: bool, seconds: float) -> void:
	var angle := TIP_ANGLE * (-1.0 if _facing_right else 1.0) if tipped else 0.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation", angle, seconds)
	await tween.finished

## The middle of the loader mouth at the back, where the junk comes out.
func mouth_global() -> Vector2:
	if _mouth == null or _mouth.polygon.is_empty():
		return global_position
	var centre := Vector2.ZERO
	for point in _mouth.polygon:
		centre += point
	return _mouth.to_global(centre / _mouth.polygon.size())

func _process(delta: float) -> void:
	var moved := global_position - _last_position
	_last_position = global_position
	if moved.length_squared() > 0.0001:
		var facing_sign := 1.0 if _facing_right else -1.0
		var direction := 1.0 if moved.x * facing_sign >= 0.0 else -1.0
		_visual.animate_wheels(moved.length() * direction, delta)
	if _reversing:
		_beep_timer -= delta
		if _beep_timer <= 0.0:
			_beep_timer = BEEP_GAP
			Sfx.play_at(&"tow_reverse_beep", global_position, -10.0)

## A low idle hum, positional, so it's there while the truck is on screen.
func _setup_engine_sound() -> void:
	var profile := EngineSoundProfile.for_engine(null)
	if profile == null:
		return
	var engine_sound := EngineSound.new()
	engine_sound.profile = profile
	engine_sound.volume_db = engine_volume_db
	engine_sound.rpm = 0.35
	engine_sound.throttle = 1.0
	add_child(engine_sound)
