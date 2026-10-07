class_name PukePuddle
extends Node2D
## What a drunk driver leaves behind (see PlayerCar's puke stop): a flat
## splat of sick on the ground decal layer, under the car, so it shows once
## the car pulls away. Sits a while like a skid mark, then weathers away.
##
## Junk Toy: one lumpy blob, its shade, and two chunks. Seeded per puddle so
## no two splats are the same shape. A stray dog (PukeDog) may come and lick
## it up, shrinking it away (`lick_away()`).

const BODY := Color(0.72, 0.7, 0.32, 1)
const SHADE := Color(0.6, 0.58, 0.25, 1)
const CHUNK := Color(0.76, 0.5, 0.26, 1)
const RADIUS := Vector2(42.0, 17.0)
const HOLD_TIME := 60.0
const FADE_TIME := 4.0

var _blob := PackedVector2Array()
var _shade := PackedVector2Array()
var _chunks: Array[PackedVector2Array] = []
var _weathering: Tween

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	var corners := 9
	for i in corners:
		var angle := TAU * i / corners + rng.randf_range(-0.15, 0.15)
		var reach := rng.randf_range(0.75, 1.15)
		_blob.append(Vector2(cos(angle) * RADIUS.x, sin(angle) * RADIUS.y) * reach)
	# The shade is the bottom strip of the same blob.
	var below := PackedVector2Array([Vector2(-RADIUS.x * 2.0, 3.0), Vector2(RADIUS.x * 2.0, 1.0),
			Vector2(RADIUS.x * 2.0, RADIUS.y * 2.0), Vector2(-RADIUS.x * 2.0, RADIUS.y * 2.0)])
	var cut := Geometry2D.intersect_polygons(_blob, below)
	if not cut.is_empty():
		_shade = cut[0]
	for i in 2:
		var at := Vector2(rng.randf_range(-22.0, 20.0), rng.randf_range(-7.0, 4.0))
		_chunks.append(PackedVector2Array([at + Vector2(-6, -4), at + Vector2(5, -5),
				at + Vector2(6, 3), at + Vector2(-4, 4)]))
	_weathering = create_tween()
	_weathering.tween_interval(HOLD_TIME)
	_weathering.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_weathering.tween_callback(queue_free)

## Licked up over `seconds`: it shrinks to nothing (in steps, a lap at a
## time) and is gone.
func lick_away(seconds: float) -> void:
	if _weathering != null:
		_weathering.kill()
	var laps := 6
	var tween := create_tween()
	for i in laps:
		tween.tween_property(self, "scale", Vector2.ONE * (1.0 - float(i + 1) / laps), seconds / laps) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

func _draw() -> void:
	draw_colored_polygon(_blob, BODY)
	if _shade.size() >= 3:
		draw_colored_polygon(_shade, SHADE)
	for chunk in _chunks:
		draw_colored_polygon(chunk, CHUNK)
