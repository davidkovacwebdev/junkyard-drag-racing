@tool
class_name WaterTower
extends StaticBody2D
## The town water tower: a fat steel tank up on three splayed legs, with one
## painted red band and a pointy cap. The tank leaks (its one gag): every few
## seconds a fat drop falls from the bottom and plinks on the ground with
## `tank_drip`. Flat polygons, origin on the ground between the legs so it
## Y-sorts against the car.

const TANK := Color(0.56, 0.6, 0.62)
const BAND := Color(0.64, 0.2, 0.17)
const LEG := UiPalette.POST_GREY
const DROP := Color(0.52, 0.72, 0.82)

const LEG_FOOT_SPREAD := 96.0
const LEG_TOP_SPREAD := 64.0
const LEG_HEIGHT := 250.0
const LEG_THICKNESS := 12.0
const TANK_HALF_WIDTH := 104.0
const TANK_HEIGHT := 124.0
const BELLY_DROP := 22.0
const ROOF_RISE := 54.0
const BAND_TOP := 0.38
const BAND_BOTTOM := 0.62

const DRIP_INTERVAL := Vector2(3.0, 6.0)
const DRIP_FALL_TIME := 0.7
const DRIP_X := 30.0
const DRIP_HEARING_RANGE := 1400.0

var _drip_wait := 0.0
var _drip_fall := -1.0
var _drip_sound: AudioStreamPlayer2D

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(LEG_FOOT_SPREAD * 2.0 + 20.0, 20.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -10.0)
	add_child(collision)
	_drip_sound = AudioStreamPlayer2D.new()
	_drip_sound.stream = Sfx.stream(&"tank_drip")
	_drip_sound.bus = SoundLibrary.bus_for(&"tank_drip")
	_drip_sound.volume_db = -12.0
	_drip_sound.max_distance = DRIP_HEARING_RANGE
	_drip_sound.position = Vector2(DRIP_X, 0.0)
	add_child(_drip_sound)
	_drip_wait = randf_range(0.0, DRIP_INTERVAL.y)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _drip_fall >= 0.0:
		_drip_fall += delta
		if _drip_fall >= DRIP_FALL_TIME:
			_drip_fall = -1.0
			_drip_sound.pitch_scale = randf_range(0.9, 1.1)
			_drip_sound.play()
		queue_redraw()
		return
	_drip_wait -= delta
	if _drip_wait <= 0.0:
		_drip_wait = randf_range(DRIP_INTERVAL.x, DRIP_INTERVAL.y)
		_drip_fall = 0.0

func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(16.0, 0.0), LEG_FOOT_SPREAD + 40.0, 18.0), UiPalette.SHADOW)
	var tank_bottom := -LEG_HEIGHT
	draw_colored_polygon(FlatProps.sliver(Vector2(0.0, -6.0), Vector2(0.0, tank_bottom), LEG_THICKNESS), LEG.darkened(0.2))
	draw_colored_polygon(FlatProps.sliver(Vector2(-LEG_FOOT_SPREAD, 0.0), Vector2(-LEG_TOP_SPREAD, tank_bottom), LEG_THICKNESS), LEG)
	draw_colored_polygon(FlatProps.sliver(Vector2(LEG_FOOT_SPREAD, 0.0), Vector2(LEG_TOP_SPREAD, tank_bottom), LEG_THICKNESS), LEG)
	draw_colored_polygon(_tank_slice(0.0, 1.0, -1.0, 1.0), TANK)
	draw_colored_polygon(_tank_slice(0.0, 1.0, 0.62, 1.0), TANK.darkened(0.2))
	draw_colored_polygon(_tank_slice(BAND_TOP, BAND_BOTTOM, -1.0, 1.0), BAND)
	var roof_base := tank_bottom - TANK_HEIGHT
	draw_colored_polygon(PackedVector2Array([
		Vector2(-TANK_HALF_WIDTH - 10.0, roof_base), Vector2(-4.0, roof_base - ROOF_RISE),
		Vector2(4.0, roof_base - ROOF_RISE), Vector2(TANK_HALF_WIDTH + 10.0, roof_base),
	]), TANK.darkened(0.25))
	if _drip_fall >= 0.0:
		var progress := _drip_fall / DRIP_FALL_TIME
		var drop_y := lerpf(tank_bottom + BELLY_DROP * (1.0 - DRIP_X / TANK_HALF_WIDTH), -8.0, progress * progress)
		draw_colored_polygon(FlatProps.octagon(Vector2(DRIP_X, drop_y), 6.0, 9.0), DROP)

## A slice of the tank, `from`..`to` down its height, across `left`..`right`
## (-1 is the left edge, 1 the right). The tank's bottom sags into a shallow V
## so it reads as a round belly, not a box.
func _tank_slice(from: float, to: float, left: float, right: float) -> PackedVector2Array:
	var top := -LEG_HEIGHT - TANK_HEIGHT * (1.0 - from)
	var bottom := -LEG_HEIGHT - TANK_HEIGHT * (1.0 - to)
	var sag := BELLY_DROP if to >= 1.0 else 0.0
	var points := PackedVector2Array([
		Vector2(TANK_HALF_WIDTH * left, top), Vector2(TANK_HALF_WIDTH * right, top),
		Vector2(TANK_HALF_WIDTH * right, bottom + sag * (1.0 - absf(right))),
	])
	if sag > 0.0 and left < 0.0 and right > 0.0:
		points.append(Vector2(0.0, bottom + sag))
	points.append(Vector2(TANK_HALF_WIDTH * left, bottom + sag * (1.0 - absf(left))))
	return points
