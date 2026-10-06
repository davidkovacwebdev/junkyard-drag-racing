class_name FishingCast
extends Node2D
## One cast of the fishing rod (items/fishing_rod.tres), stuck out of the
## car's window: the bobber arcs out to `spot` in the sea, bobs there a while,
## dips under when something bites, and is reeled back in. `finished` says
## whether anything was on the hook; PlayerCar decides what it was.
##
## A child of the car, drawn just over it: the rod (a chunky pole), the line
## and a red-and-white bobber, plus a foam splash where it lands and bites.
## `cancel()` (the player driving off) reels in empty-handed.

signal finished(caught: bool, spot: Vector2)

enum Stage { CAST, WAIT, BITE, REEL }

const POLE_COLOR := Color(0.55, 0.4, 0.28)
const LINE_COLOR := Color(0.85, 0.85, 0.8)
const BOBBER_COLOR := Color(0.75, 0.2, 0.15)
const BOBBER_TOP_COLOR := Color(0.9, 0.9, 0.86)
const FOAM_COLOR := Color("d8ece8")

@export var cast_seconds: float = 0.5
@export var wait_seconds: Vector2 = Vector2(2.0, 4.5)
@export var bite_seconds: float = 0.9
@export var reel_seconds: float = 0.7
@export var cast_arc: float = 90.0
@export var pole_base: Vector2 = Vector2(0.0, -18.0)
@export var pole_reach: Vector2 = Vector2(56.0, -58.0)
@export var pole_thickness: float = 6.0
@export var line_thickness: float = 4.0
@export var bobber_radius: float = 9.0

## Where the bobber lands, in world space.
var spot: Vector2

var _stage: Stage = Stage.CAST
var _time: float = 0.0
var _wait: float = 0.0
var _caught: bool = false
## Where the reel-in starts from (the bobber's spot when it began).
var _reel_from: Vector2
var _splash_time: float = -1.0

func _ready() -> void:
	z_index = 1
	_wait = randf_range(wait_seconds.x, wait_seconds.y)
	Sfx.play(&"rod_cast", -4.0, 0.05)

## Reel in now with nothing on the hook.
func cancel() -> void:
	if _stage == Stage.REEL:
		return
	_caught = false
	_start_reel()

func _process(delta: float) -> void:
	_time += delta
	if _splash_time >= 0.0:
		_splash_time += delta
	match _stage:
		Stage.CAST:
			if _time >= cast_seconds:
				_next(Stage.WAIT)
				_splash()
		Stage.WAIT:
			if _time >= _wait:
				_next(Stage.BITE)
				_splash()
		Stage.BITE:
			if _time >= bite_seconds * 0.5 and _time - delta < bite_seconds * 0.5:
				_splash()
			if _time >= bite_seconds:
				_caught = true
				_start_reel()
		Stage.REEL:
			if _time >= reel_seconds:
				finished.emit(_caught, spot)
				queue_free()
				return
	queue_redraw()

func _next(stage: Stage) -> void:
	_stage = stage
	_time = 0.0

func _start_reel() -> void:
	_reel_from = _bobber_global()
	_next(Stage.REEL)
	Sfx.play(&"reel_whirr", -6.0, 0.05)

func _splash() -> void:
	_splash_time = 0.0
	Sfx.play_at(&"bobber_plop", spot, -4.0)

## Which way the rod points: toward the water.
func _side() -> float:
	return 1.0 if spot.x >= global_position.x else -1.0

func _tip_local() -> Vector2:
	return pole_base + Vector2(pole_reach.x * _side(), pole_reach.y)

func _bobber_global() -> Vector2:
	var tip := to_global(_tip_local())
	match _stage:
		Stage.CAST:
			var t := clampf(_time / cast_seconds, 0.0, 1.0)
			return tip.lerp(spot, t) + Vector2(0.0, -cast_arc * sin(PI * t))
		Stage.WAIT:
			return spot + Vector2(0.0, sin(_time * 3.0) * 2.0)
		Stage.BITE:
			return spot + Vector2(0.0, absf(sin(_time / bite_seconds * TAU)) * 8.0)
		_:
			var t := clampf(_time / reel_seconds, 0.0, 1.0)
			return _reel_from.lerp(tip, t * t) + Vector2(0.0, -cast_arc * 0.5 * sin(PI * t))

func _draw() -> void:
	var tip := _tip_local()
	var bobber := to_local(_bobber_global())
	if _splash_time >= 0.0 and _splash_time < 0.6:
		var grow := _splash_time / 0.6
		var splash_color := FOAM_COLOR
		splash_color.a = 1.0 - grow
		draw_colored_polygon(FlatProps.octagon(to_local(spot), 10.0 + grow * 22.0, (10.0 + grow * 22.0) * 0.4), splash_color)
	draw_colored_polygon(FlatProps.sliver(pole_base, tip, pole_thickness), POLE_COLOR)
	draw_colored_polygon(FlatProps.sliver(tip, bobber, line_thickness), LINE_COLOR)
	var r := bobber_radius
	draw_colored_polygon(PackedVector2Array([
		bobber + Vector2(-r, 0.0), bobber + Vector2(r, 0.0),
		bobber + Vector2(r * 0.6, r), bobber + Vector2(-r * 0.6, r),
	]), BOBBER_COLOR)
	draw_colored_polygon(PackedVector2Array([
		bobber + Vector2(-r, 0.0), bobber + Vector2(r, 0.0),
		bobber + Vector2(r * 0.6, -r * 0.8), bobber + Vector2(-r * 0.6, -r * 0.8),
	]), BOBBER_TOP_COLOR)
