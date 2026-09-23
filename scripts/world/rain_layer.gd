class_name RainLayer
extends Node2D
## Falling rain, drawn as flat streaks in a box that follows the camera.
##
## The node parks on the camera's centre every frame and only paints the slice
## of sky the camera can see (the same `get_global_transform_with_canvas()`
## trick `Water` uses), so it works at every zoom level and the drops wrap
## around instead of running out. Alpha comes straight off `Weather`, so rain
## builds as a shower arrives and thins out as it passes.
##
## Draw order: give it a high `z_index` in the scene (main.tscn uses 900) so it
## falls in front of the cars, and leave it low in the tree — the HUD lives in
## a CanvasLayer, which draws over the whole 2D world regardless.
##
## The streaks are `draw_line`, not polygon art — this is weather, not a prop,
## so it doesn't fall under the flat-fill/no-outlines rule that governs the
## houses, trees and puddles.

@export_group("Drops")
## How many streaks are alive at once. Only a slice is ever on screen; the
## rest are wrapped around the camera.
@export var drop_count: int = 320
## Falling speed range, px per second, and how much the wind pushes drops
## sideways. A constant sideways push is what makes a shower look windy rather
## than like a hanging bead curtain.
@export var fall_speed_min: float = 900.0
@export var fall_speed_max: float = 1500.0
@export var wind: float = -170.0
## Drawn length of a streak, and its width.
@export var streak_length: float = 46.0
@export var line_width: float = 3.0
## Extra room drawn past the viewport edge so a drop never pops in mid-screen.
@export var view_margin: float = 260.0

@export_group("Look")
@export var drop_color: Color = Color(0.79, 0.87, 0.95, 0.45)

## Fallback box, used when there's no camera to measure (headless, or a scene
## without one). Matches the visible area at zoom 1 on the default window.
const FALLBACK_RECT := Rect2(-1400.0, -900.0, 2800.0, 1800.0)

## x, y (local position) and z (this drop's fall speed).
var _drops: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 1337
	# Seeded across the fallback box; wherever the camera actually is, the
	# first wrap pulls them into view.
	for i in drop_count:
		_drops.append(Vector3(
			_rng.randf_range(FALLBACK_RECT.position.x, FALLBACK_RECT.end.x),
			_rng.randf_range(FALLBACK_RECT.position.y, FALLBACK_RECT.end.y),
			_rng.randf_range(fall_speed_min, fall_speed_max)))
	visible = false

func _process(delta: float) -> void:
	var intensity := Weather.get_rain_intensity()
	visible = intensity > 0.02
	if not visible:
		return

	# Ride the camera so the box is always the part of the world on screen.
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		global_position = camera.get_screen_center_position()

	var rect := _visible_rect()
	_advance(delta, rect)
	queue_redraw()

## Move every drop down and sideways, recycling it to the top of the box once
## it falls out of the bottom.
func _advance(delta: float, rect: Rect2) -> void:
	for i in _drops.size():
		var drop := _drops[i]
		drop.x += wind * delta
		drop.y += drop.z * delta
		if drop.y > rect.end.y:
			drop.y = rect.position.y - _rng.randf_range(0.0, 90.0)
			drop.x = _rng.randf_range(rect.position.x, rect.end.x)
		if drop.x < rect.position.x:
			drop.x += rect.size.x
		elif drop.x > rect.end.x:
			drop.x -= rect.size.x
		_drops[i] = drop

func _draw() -> void:
	var alpha := Weather.get_rain_intensity()
	var color := drop_color
	color.a *= alpha
	# Streak direction is the drops' own velocity, so the angle leans with the
	# wind instead of falling dead vertical while drifting sideways.
	var direction := Vector2(wind, (fall_speed_min + fall_speed_max) * 0.5).normalized()
	var tail := direction * streak_length
	for drop in _drops:
		var head := Vector2(drop.x, drop.y)
		draw_line(head - tail, head, color, line_width, true)

## The part of this node's own space the camera can see, grown by
## `view_margin`. Same measurement `Water` makes, for the same reason: it keeps
## working at any zoom without anyone handing us the camera's scale.
func _visible_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return FALLBACK_RECT
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var vp := viewport.get_visible_rect()
	var corner_a := to_local * vp.position
	var corner_b := to_local * vp.end
	var rect := Rect2(corner_a, corner_b - corner_a).abs()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return FALLBACK_RECT
	return rect.grow(view_margin)
