class_name TowTruck
extends Node2D
## Hank's tow truck, only ever seen in the tow rescue cutscene
## (TowTruckRescueCutscene). The same CarView rig as the garbage truck, moved
## by tweens rather than physics: it backs in, winches a car out on a cable
## from the hook on its boom, and drives off again.

const SCENE := preload("res://scenes/world/tow_truck/tow_truck.tscn")
const BODY_PATH := "res://scenes/world/tow_truck/tow_truck_body.tscn"
const WHEEL_PATH := "res://scenes/parts/wheels/wheel_standard.tscn"
const CABLE_COLOR := Color(0.18, 0.18, 0.19)
const CABLE_THICKNESS := 6.0

@export var engine_volume_db: float = -16.0

## While set, a cable runs from the boom's hook to this node.
var cable_target: Node2D = null:
	set(value):
		cable_target = value
		queue_redraw()

var _facing_right: bool = true
var _last_position: Vector2
var _hook: Marker2D = null

@onready var _visual: CarView = $Visual as CarView

static func spawn(parent: Node, at: Vector2, facing_right: bool) -> TowTruck:
	var truck := SCENE.instantiate() as TowTruck
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
	_hook = _visual.find_child("HookMount", true, false) as Marker2D
	_setup_engine_sound()

func face(right: bool) -> void:
	_facing_right = right
	_visual.scale.x = 1.0 if right else -1.0

func drive_to(to: Vector2, seconds: float) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", to, seconds)
	return tween

func hook_global() -> Vector2:
	return _hook.global_position if _hook != null else global_position

func _process(delta: float) -> void:
	var moved := global_position - _last_position
	_last_position = global_position
	if moved.length_squared() > 0.0001:
		var facing_sign := 1.0 if _facing_right else -1.0
		var direction := 1.0 if moved.x * facing_sign >= 0.0 else -1.0
		_visual.animate_wheels(moved.length() * direction, delta)
	if is_instance_valid(cable_target):
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(cable_target):
		return
	var from := to_local(hook_global())
	var to := to_local(cable_target.global_position)
	draw_colored_polygon(FlatProps.sliver(from, to, CABLE_THICKNESS), CABLE_COLOR)

## A low idle hum, positional, so it's there while the truck is on screen.
func _setup_engine_sound() -> void:
	var profile := EngineSoundProfile.for_engine(null)
	if profile == null:
		return
	var engine_sound := EngineSound.new()
	engine_sound.profile = profile
	engine_sound.volume_db = engine_volume_db
	engine_sound.rpm = 0.3
	engine_sound.throttle = 1.0
	add_child(engine_sound)
