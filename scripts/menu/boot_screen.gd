class_name BootScreen
extends Control
## The first screen the game opens on. The Upside-Down Car rolls down the
## street while the main menu loads in the background, then floors it off
## screen into the menu. No music until the menu is up.
##
## The car is copied from the real part scenes, so it follows their art. Its
## first frame is also the engine's boot splash image (rendered by
## tools/render_boot_splash.tscn), so the splash hands over seamlessly.

const NEXT_SCENE := "res://scenes/menu/main_menu.tscn"
const BODY_SCENE := preload("res://scenes/parts/bodies/body_upside_down_car.tscn")
const WHEEL_SCENE := preload("res://scenes/parts/wheels/wheel_standard.tscn")

## Shortest time on screen, so a fast load still shows the car rolling.
const MIN_SHOW_TIME := 1.8
const CAR_SCALE := 2.0
const WHEEL_RADIUS := 36.0
const STREET_HEIGHT := 150.0
const CURB_HEIGHT := 10.0
const LANE_CENTRE_Y := 66.0
const WHEEL_CONTACT_Y := 118.0
const DASH_SIZE := Vector2(70.0, 10.0)
const DASH_SPACING := 180.0
const CRUISE_SPEED := 420.0
const LEAVE_SPEED := 1600.0
const LEAVE_TIME := 0.9
const RATTLE_HEIGHT := 2.0
const RATTLE_SPEED := 14.0

## Off for the splash render: the car holds its first frame and nothing loads.
@export var play_on_ready := true

@onready var _street: Control = $Street
@onready var _car: Node2D = $Car

var _car_body := Node2D.new()
var _wheels: Array[Node2D] = []
var _wheel_bottom_y := 0.0
var _time := 0.0
var _road_speed := CRUISE_SPEED
var _road_offset := 0.0
var _leaving := false

func _ready() -> void:
	_build_car()
	_street.draw.connect(_draw_street)
	resized.connect(_place_car)
	_place_car()
	if not play_on_ready:
		set_process(false)
		return
	Music.hush(true, 0.0)
	ResourceLoader.load_threaded_request(NEXT_SCENE)
	Sfx.play(&"ignition_click", -8.0)

func _process(delta: float) -> void:
	_time += delta
	_road_offset = fposmod(_road_offset + _road_speed * delta, DASH_SPACING)
	var wheel_turn := _road_speed * delta / (WHEEL_RADIUS * CAR_SCALE)
	for wheel in _wheels:
		wheel.rotation += wheel_turn
	_car_body.position.y = -absf(sin(_time * RATTLE_SPEED)) * RATTLE_HEIGHT
	_street.queue_redraw()

	if _leaving or _time < MIN_SHOW_TIME:
		return
	var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE)
	if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_drive_off(status == ResourceLoader.THREAD_LOAD_LOADED)

func _drive_off(loaded: bool) -> void:
	_leaving = true
	Sfx.play(&"backfire", -4.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_road_speed", LEAVE_SPEED, LEAVE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_car, "position:x", size.x + 200.0 * CAR_SCALE, LEAVE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	Music.hush(false)
	if loaded:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(NEXT_SCENE))
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)

func _build_car() -> void:
	_car.scale = Vector2.ONE * CAR_SCALE
	_car.add_child(_car_body)
	var body := BODY_SCENE.instantiate()
	for child in body.get_children():
		if child is Polygon2D:
			_car_body.add_child(child.duplicate())
		elif child is Marker2D and child.name.begins_with("WheelMount"):
			var wheel := _polygons_of(WHEEL_SCENE)
			wheel.position = child.position
			_car.add_child(wheel)
			_wheels.append(wheel)
			_wheel_bottom_y = child.position.y + WHEEL_RADIUS
	body.free()

## Just the drawn polygons of a part scene, without its physics or scripts.
static func _polygons_of(scene: PackedScene) -> Node2D:
	var source := scene.instantiate()
	var copy := Node2D.new()
	for child in source.get_children():
		if child is Polygon2D:
			copy.add_child(child.duplicate())
	source.free()
	return copy

func _place_car() -> void:
	if _leaving:
		return
	var contact_y := size.y - STREET_HEIGHT + WHEEL_CONTACT_Y
	_car.position = Vector2(size.x * 0.5, contact_y - _wheel_bottom_y * CAR_SCALE)
	_street.queue_redraw()

func _draw_street() -> void:
	var width := _street.size.x
	var top := _street.size.y - STREET_HEIGHT
	_street.draw_rect(Rect2(0.0, top, width, STREET_HEIGHT), UiPalette.METAL_GREY)
	_street.draw_rect(Rect2(0.0, top, width, CURB_HEIGHT), UiPalette.POST_GREY)
	var x := -_road_offset
	while x < width:
		_street.draw_rect(Rect2(x, top + LANE_CENTRE_Y - DASH_SIZE.y * 0.5, DASH_SIZE.x, DASH_SIZE.y), UiPalette.ACCENT_YELLOW)
		x += DASH_SPACING
	var shadow_centre := Vector2(_car.position.x, top + WHEEL_CONTACT_Y)
	_street.draw_colored_polygon(FlatProps.octagon(shadow_centre, 150.0 * CAR_SCALE, 7.0), UiPalette.SHADOW)
