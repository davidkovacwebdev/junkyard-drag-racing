class_name RainLayer
extends Node2D
## Falling rain, drawn as flat streaks tiled across the world.
##
## One tile's worth of drops is simulated and stamped across every tile the
## camera can see, so the rain covers the whole view at any zoom level while
## the per-frame work stays one small tile. All streaks go out as one
## TriangleBatch, and the rain fades out when zoomed out far enough that the
## streaks would be specks anyway. Alpha comes straight off `Weather`, so rain builds as
## a shower arrives and thins out as it passes.
##
## Draw order: give it a high `z_index` in the scene (main.tscn uses 900) so it
## falls in front of the cars, and leave it low in the tree — the HUD lives in
## a CanvasLayer, which draws over the whole 2D world regardless.
##
## The streaks are lines, not polygon art — this is weather, not a prop, so it
## doesn't fall under the flat-fill/no-outlines rule that governs the houses,
## trees and puddles.

@export_group("Drops")
## Streaks per tile. The tile repeats across the view, so this sets density.
@export var drops_per_tile: int = 200
## World size of the repeating tile. Big enough that the repeat isn't obvious
## when zoomed out.
@export var tile_size: Vector2 = Vector2(2400.0, 1600.0)
## Falling speed range, px per second, and how much the wind pushes drops
## sideways. A constant sideways push is what makes a shower look windy rather
## than like a hanging bead curtain.
@export var fall_speed_min: float = 900.0
@export var fall_speed_max: float = 1500.0
@export var wind: float = -170.0
## Drawn length of a streak, and its width.
@export var streak_length: float = 46.0
@export var line_width: float = 3.0

@export_group("Look")
@export var drop_color: Color = Color(0.79, 0.87, 0.95, 0.45)

## Rain is fully drawn at `FULL_ZOOM` and gone by `HIDDEN_ZOOM`.
const FULL_ZOOM := 0.3
const HIDDEN_ZOOM := 0.15
## Used when there's no viewport to measure (headless).
const FALLBACK_RECT := Rect2(-1400.0, -900.0, 2800.0, 1800.0)

## x, y (position inside the tile) and z (this drop's fall speed).
var _drops: Array[Vector3] = []
var _streak_points := PackedVector2Array()
var _rain_sound: SustainedSound

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in drops_per_tile:
		_drops.append(Vector3(
			rng.randf_range(0.0, tile_size.x),
			rng.randf_range(0.0, tile_size.y),
			rng.randf_range(fall_speed_min, fall_speed_max)))
	visible = false
	_rain_sound = SustainedSound.new()
	_rain_sound.sound_name = &"rain_loop"
	_rain_sound.base_volume_db = -8.0
	_rain_sound.fade_in_time = 1.5
	_rain_sound.fade_out_time = 2.0
	add_child(_rain_sound)

func _process(delta: float) -> void:
	var intensity := Weather.get_rain_intensity()
	_rain_sound.set_level(intensity)
	visible = intensity * _zoom_fade() > 0.02
	if not visible:
		return
	_advance(delta)
	queue_redraw()

func _advance(delta: float) -> void:
	for i in _drops.size():
		var drop := _drops[i]
		drop.x = fposmod(drop.x + wind * delta, tile_size.x)
		drop.y = fposmod(drop.y + drop.z * delta, tile_size.y)
		_drops[i] = drop

func _draw() -> void:
	var color := drop_color
	color.a *= Weather.get_rain_intensity() * _zoom_fade()
	# Streak direction is the drops' own velocity, so the angle leans with the
	# wind instead of falling dead vertical while drifting sideways.
	var direction := Vector2(wind, (fall_speed_min + fall_speed_max) * 0.5).normalized()
	var tail := direction * streak_length
	var view := _visible_rect().grow(streak_length)
	var first_tile_x := floori(view.position.x / tile_size.x)
	var first_tile_y := floori(view.position.y / tile_size.y)
	var last_tile_x := floori(view.end.x / tile_size.x)
	var last_tile_y := floori(view.end.y / tile_size.y)

	_streak_points.clear()
	for tile_y in range(first_tile_y, last_tile_y + 1):
		for tile_x in range(first_tile_x, last_tile_x + 1):
			var tile_origin := Vector2(tile_x * tile_size.x, tile_y * tile_size.y)
			for drop in _drops:
				var head := tile_origin + Vector2(drop.x, drop.y)
				if view.has_point(head):
					_streak_points.append(head - tail)
					_streak_points.append(head)
	var batch := TriangleBatch.new()
	batch.add_segments(_streak_points, color, line_width)
	batch.commit(self)

func _zoom_fade() -> float:
	var zoom := get_global_transform_with_canvas().get_scale().x
	return clampf(inverse_lerp(HIDDEN_ZOOM, FULL_ZOOM, zoom), 0.0, 1.0)

## The part of this node's space the camera can see. Measured through the
## canvas transform so it works at any zoom without needing the camera itself.
func _visible_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return FALLBACK_RECT
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var viewport_rect := viewport.get_visible_rect()
	var corner_a := to_local * viewport_rect.position
	var corner_b := to_local * viewport_rect.end
	var rect := Rect2(corner_a, corner_b - corner_a).abs()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return FALLBACK_RECT
	return rect
