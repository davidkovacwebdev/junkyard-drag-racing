class_name PickupTruck
extends Node2D
## Clyde's beat-up white pickup, only seen in the fishing eviction cutscene
## (LandownerCutscene). Moved by tweens, not physics: it tears up, stops by
## the car, and leaves again.
##
## The driver rides in the cab and talks out of the open window: the truck
## draws the dark cab behind him, and its `_front` child draws the body over
## him with a gap where the window is, so only his head and shoulders show.
##
## Junk-toy style: chassis, bed, cab roof and two pillars, door, hood, one shade strip
## along the bottom, a door handle, bumper and headlight, two wheels with
## hubcaps. Authored facing right; `face(false)` mirrors it. Origin on the
## ground between the wheels.

const WHITE := Color(0.92, 0.91, 0.87, 1)
const WHITE_SHADE := Color(0.76, 0.75, 0.71, 1)
const CAB_DARK := Color(0.16, 0.17, 0.19, 1)
const TYRE := Color(0.14, 0.14, 0.15, 1)
const HUB := Color(0.62, 0.62, 0.6, 1)
const BUMPER := Color(0.45, 0.45, 0.44, 1)
const LAMP := UiPalette.ACCENT_YELLOW
const WHEELS: Array[Vector2] = [Vector2(-115.0, -28.0), Vector2(110.0, -28.0)]
const WHEEL_RADIUS := 28.0
const ACTOR_SCALE := 0.55
const FRONT_Z := 30
## Where the driver stands in the cab so his head sits in the window.
const DRIVER_AT := Vector2(40.0, -12.0)

@export var engine_volume_db: float = -14.0

var driver: CutsceneActor

var _front: Node2D
var _facing_right := true
var _last_position := Vector2.ZERO
var _bob := 0.0

static func spawn(parent: Node, at: Vector2, facing_right: bool, driver_data: CharacterData) -> PickupTruck:
	var truck := PickupTruck.new()
	truck._setup(driver_data)
	parent.add_child(truck)
	truck.global_position = at
	truck._last_position = at
	truck.face(facing_right)
	return truck

func _setup(driver_data: CharacterData) -> void:
	driver = CutsceneActor.new()
	driver.setup(driver_data, ACTOR_SCALE)
	driver.position = DRIVER_AT
	add_child(driver)
	_front = Node2D.new()
	# Over every layer the character's parts use (up to tears and props).
	_front.z_index = FRONT_Z
	_front.draw.connect(_draw_front)
	add_child(_front)

func _ready() -> void:
	var profile := EngineSoundProfile.for_engine(null)
	if profile != null:
		var engine_sound := EngineSound.new()
		engine_sound.profile = profile
		engine_sound.volume_db = engine_volume_db
		engine_sound.rpm = 0.35
		engine_sound.throttle = 1.0
		add_child(engine_sound)

func face(right: bool) -> void:
	_facing_right = right
	scale.x = 1.0 if right else -1.0

func drive_to(to: Vector2, seconds: float) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", to, seconds)
	return tween

## A rattly bounce while it's moving.
func _process(delta: float) -> void:
	var moved := global_position - _last_position
	_last_position = global_position
	_bob = -absf(sin(Time.get_ticks_msec() * 0.03)) * 3.0 if moved.length() > 0.5 else 0.0
	_front.position.y = _bob
	driver.position.y = DRIVER_AT.y + _bob
	queue_redraw()
	_front.queue_redraw()

## Behind the driver: the dark inside of the cab.
func _draw() -> void:
	draw_rect(Rect2(-10.0, -150.0 + _bob, 100.0, 60.0), CAB_DARK)

## Over the driver: the body, with the window left open.
func _draw_front() -> void:
	var f := _front
	# The dark chassis underneath, between the wheels (it hides the driver's
	# boots too).
	f.draw_rect(Rect2(-150.0, -34.0, 280.0, 26.0), CAB_DARK)
	# Bed, door and hood.
	f.draw_rect(Rect2(-175.0, -96.0, 165.0, 66.0), WHITE)
	f.draw_rect(Rect2(-10.0, -98.0, 110.0, 68.0), WHITE)
	f.draw_colored_polygon(PackedVector2Array([Vector2(100.0, -98.0), Vector2(150.0, -88.0),
			Vector2(168.0, -70.0), Vector2(168.0, -30.0), Vector2(100.0, -30.0)]), WHITE)
	# Cab roof, back pillar and the slanted front pillar round the window.
	f.draw_rect(Rect2(-12.0, -160.0, 100.0, 14.0), WHITE)
	f.draw_rect(Rect2(-12.0, -150.0, 14.0, 54.0), WHITE)
	f.draw_colored_polygon(PackedVector2Array([Vector2(76.0, -160.0), Vector2(90.0, -160.0),
			Vector2(112.0, -96.0), Vector2(96.0, -96.0)]), WHITE)
	# One shade strip along the bottom, the door handle, bumper and lamp.
	f.draw_rect(Rect2(-175.0, -44.0, 343.0, 14.0), WHITE_SHADE)
	f.draw_rect(Rect2(66.0, -84.0, 20.0, 7.0), CAB_DARK)
	f.draw_rect(Rect2(158.0, -40.0, 18.0, 16.0), BUMPER)
	f.draw_rect(Rect2(154.0, -78.0, 12.0, 12.0), LAMP)
	for at in WHEELS:
		f.draw_colored_polygon(FlatProps.octagon(at, WHEEL_RADIUS, WHEEL_RADIUS), TYRE)
		f.draw_colored_polygon(FlatProps.octagon(at, WHEEL_RADIUS * 0.45, WHEEL_RADIUS * 0.45), HUB)
