@tool
class_name DerbyArenaArt
extends Node2D
## The derby pit the cars are drawn in: a churned mud floor, a plank fence
## along the back with a few spectators leaning over it, a DERBY banner on
## the fence and two floodlight poles. The tyre walls at either end are the
## arena's own EndWallArt.

@export var arena_width := 2800.0
@export var art_seed := 5

const MUD := Color(0.42, 0.32, 0.22)
const MUD_SHADE := Color(0.34, 0.26, 0.18)
const MUD_PATCH := Color(0.36, 0.27, 0.19)
const FENCE := Color(0.55, 0.42, 0.28)
const FENCE_SHADE := Color(0.45, 0.34, 0.22)
const BANNER := Color(0.85, 0.66, 0.12)
const LAMP := Color(0.96, 0.9, 0.62)
const SHIRTS: Array[Color] = [
	Color(0.62, 0.22, 0.18), Color(0.30, 0.40, 0.55), Color(0.72, 0.58, 0.25),
	Color(0.40, 0.48, 0.30), Color(0.55, 0.38, 0.50),
]

const FLOOR_DEPTH := 700.0
const FLOOR_SHADE_TOP := 60.0
const FENCE_HEIGHT := 240.0
const FENCE_SHADE_HEIGHT := 36.0
const SPECTATORS := 7
const MUD_PATCHES := 5
const BANNER_SIZE := Vector2(560.0, 90.0)
const POLE_HEIGHT := 820.0
const POLE_XS: Array[float] = [260.0, 2540.0]

var _art := TriangleBatch.new()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = art_seed
	var left := -200.0
	var right := arena_width + 200.0
	_art.clear()
	for pole_x in POLE_XS:
		_draw_floodlight(pole_x)
	_draw_spectators(rng)
	_art.draw_rect(Rect2(left, -FENCE_HEIGHT, right - left, FENCE_HEIGHT), FENCE)
	_art.draw_rect(Rect2(left, -FENCE_SHADE_HEIGHT, right - left, FENCE_SHADE_HEIGHT), FENCE_SHADE)
	var banner := _banner_rect()
	_art.draw_rect(banner, BANNER)
	_art.draw_rect(Rect2(banner.end.x - 16.0, banner.position.y, 16.0, banner.size.y), BANNER.darkened(0.2))
	_art.draw_rect(Rect2(left, 0.0, right - left, FLOOR_DEPTH), MUD)
	_art.draw_rect(Rect2(left, FLOOR_SHADE_TOP, right - left, FLOOR_DEPTH - FLOOR_SHADE_TOP), MUD_SHADE)
	for i in MUD_PATCHES:
		var center := Vector2(rng.randf_range(200.0, arena_width - 200.0), rng.randf_range(110.0, 400.0))
		_art.draw_colored_polygon(FlatProps.octagon(center, rng.randf_range(120.0, 220.0), rng.randf_range(24.0, 40.0)), MUD_PATCH)
	_art.commit(self)
	_art.clear()
	draw_string(ThemeDB.fallback_font, banner.position + Vector2(0.0, 64.0), "DEMOLITION DERBY",
			HORIZONTAL_ALIGNMENT_CENTER, banner.size.x - 16.0, 52, UiPalette.DANGER_RED)

func _banner_rect() -> Rect2:
	return Rect2(arena_width * 0.5 - BANNER_SIZE.x * 0.5, -FENCE_HEIGHT + 50.0, BANNER_SIZE.x, BANNER_SIZE.y)

## Shoulders and a head poking over the fence, spaced well apart.
func _draw_spectators(rng: RandomNumberGenerator) -> void:
	var banner := _banner_rect()
	for i in SPECTATORS:
		var x := lerpf(120.0, arena_width - 120.0, (i + rng.randf_range(0.3, 0.7)) / float(SPECTATORS))
		if x > banner.position.x - 40.0 and x < banner.end.x + 40.0:
			continue
		var shoulders := Vector2(x, -FENCE_HEIGHT + 10.0)
		_art.draw_colored_polygon(FlatProps.octagon(shoulders, 46.0, 40.0), SHIRTS[rng.randi() % SHIRTS.size()])
		_art.draw_colored_polygon(FlatProps.octagon(shoulders + Vector2(0.0, -62.0), 26.0, 28.0), UiPalette.CARDBOARD_LIGHT)

func _draw_floodlight(x: float) -> void:
	var top := -POLE_HEIGHT
	_art.draw_rect(Rect2(x - 9.0, top, 18.0, POLE_HEIGHT), UiPalette.POST_GREY)
	_art.draw_rect(Rect2(x - 70.0, top - 50.0, 140.0, 56.0), UiPalette.STEEL_DARK)
	_art.draw_rect(Rect2(x - 58.0, top - 40.0, 116.0, 30.0), LAMP)
