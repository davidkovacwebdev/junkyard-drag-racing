class_name SleepTransition
extends Control
## The garage's Zz button: the screen fades in on the dark junk heap and tilts
## up to the night sky, the moon sinks, the stars go out one by one and the sun
## comes up as the sky warms to day. The clock jumps to the next morning (with
## the rooster) once the sun is well up, then the screen fades back to the
## garage and `finished` fires.

signal finished

const FADE_TIME := 0.5
## The view starts this far (as a fraction of the screen) down on the heap
## and tilts up to the sky over LOOK_UP_TIME.
const LOOK_DOWN_START := 0.6
const LOOK_UP_TIME := 1.8
const NIGHT_HOLD := 0.8
const SKY_CHANGE_TIME := 3.6
const DAY_HOLD := 0.8
## How far through the sky change the moon is down behind the hills.
const MOON_DOWN_AT := 0.55
## How far through the sky change morning comes and the rooster crows.
const WAKE_AT := 0.8

const SKY_TOP_NIGHT := Color(0.07, 0.08, 0.16)
const SKY_TOP_DAWN := Color(0.30, 0.24, 0.38)
const SKY_TOP_DAY := Color(0.45, 0.62, 0.78)
const SKY_BAND_NIGHT := Color(0.12, 0.13, 0.24)
const SKY_BAND_DAWN := Color(0.80, 0.50, 0.34)
const SKY_BAND_DAY := Color(0.66, 0.78, 0.84)
const HILL_NIGHT := Color(0.13, 0.13, 0.20)
const HILL_DAY := Color(0.46, 0.52, 0.46)
const HEAP_NIGHT := Color(0.09, 0.08, 0.09)
const HEAP_DAY := Color(0.40, 0.33, 0.24)
const MOON_COLOR := Color(0.86, 0.84, 0.74)
const STAR_COLOR := Color(0.90, 0.88, 0.74)
const SUN_COLOR := Color(0.95, 0.72, 0.30)
const SUN_RAY_COLOR := Color(0.95, 0.80, 0.42)

const STAR_COUNT := 9
const STAR_SEED := 77
## How close (as a fraction of the screen) a star may sit to another or the moon.
const STAR_SPACING := 0.12
## Where the moon hangs at the start of the night, as a fraction of the screen.
const MOON_START := Vector2(0.70, 0.20)

## 0 = deep night, 1 = full morning.
var _sky_progress: float = 0.0:
	set(value):
		_sky_progress = value
		if not _woken and _sky_progress >= WAKE_AT:
			_wake_up()
		queue_redraw()
## How far down the view still is, as a fraction of the screen (0 = the sky).
var _look_down: float = LOOK_DOWN_START:
	set(value):
		_look_down = value
		queue_redraw()
var _woken: bool = false
var _star_spots: Array[Vector3] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	_scatter_stars()
	_play()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()

func _play() -> void:
	Sfx.play(&"sleep_snore", -6.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	tween.parallel().tween_property(self, "_look_down", 0.0, LOOK_UP_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Sfx.play.bind(&"sleep_snore", -8.0, 0.1))
	tween.tween_interval(NIGHT_HOLD)
	tween.tween_property(self, "_sky_progress", 1.0, SKY_CHANGE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(DAY_HOLD)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_finish)

func _wake_up() -> void:
	_woken = true
	DayNightCycle.skip_to_next_morning()
	SaveSystem.save_game()

func _finish() -> void:
	finished.emit()
	queue_free()

## Each star is (x, y) as a fraction of the screen, and z the point in the
## sky change where it goes out, so they wink out one after another.
func _scatter_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	var taken: Array[Vector2] = [MOON_START]
	while _star_spots.size() < STAR_COUNT:
		var spot := Vector2(rng.randf_range(0.04, 0.96), rng.randf_range(0.05, 0.45))
		if taken.any(func(other: Vector2) -> bool: return spot.distance_to(other) < STAR_SPACING):
			continue
		taken.append(spot)
		var goes_out := 0.15 + 0.3 * float(_star_spots.size()) / STAR_COUNT
		_star_spots.append(Vector3(spot.x, spot.y, goes_out))

func _draw() -> void:
	var horizon_y := size.y * 0.72
	var band_top := horizon_y - size.y * 0.24
	draw_set_transform(Vector2(0.0, -_look_down * size.y))
	draw_rect(Rect2(0.0, 0.0, size.x, band_top), _sky_color(SKY_TOP_NIGHT, SKY_TOP_DAWN, SKY_TOP_DAY))
	draw_rect(Rect2(0.0, band_top, size.x, horizon_y - band_top + 4.0), _sky_color(SKY_BAND_NIGHT, SKY_BAND_DAWN, SKY_BAND_DAY))
	_draw_stars()
	_draw_moon(horizon_y)
	_draw_sun(horizon_y)
	_draw_hills(horizon_y)

## Night to dawn over the first half of the change, dawn to day over the rest.
func _sky_color(night: Color, dawn: Color, day: Color) -> Color:
	if _sky_progress < 0.5:
		return night.lerp(dawn, _sky_progress / 0.5)
	return dawn.lerp(day, (_sky_progress - 0.5) / 0.5)

func _draw_stars() -> void:
	var star_radius := maxf(size.y * 0.012, 6.0)
	for star in _star_spots:
		var shown := clampf(1.0 - (_sky_progress - star.z) / 0.12, 0.0, 1.0)
		if shown <= 0.0:
			continue
		var center := Vector2(star.x * size.x, star.y * size.y)
		var points := PackedVector2Array()
		for k in 8:
			var reach := star_radius if k % 2 == 0 else star_radius * 0.4
			points.append(center + Vector2.from_angle(TAU * k / 8.0 + 0.2) * reach)
		draw_colored_polygon(points, Color(STAR_COLOR, shown))

## A fat crescent sinking from high on the right down behind the hills.
func _draw_moon(horizon_y: float) -> void:
	var moon_set := clampf(_sky_progress / MOON_DOWN_AT, 0.0, 1.0)
	var radius := size.y * 0.075
	var high := MOON_START * size
	var low := Vector2(size.x * 0.88, horizon_y + radius * 1.6)
	var center := Vector2(lerpf(high.x, low.x, moon_set), lerpf(high.y, low.y, moon_set * moon_set))
	var tilt := deg_to_rad(-18.0)
	# The moon disc minus the same disc shifted left, the two meeting at the tips.
	var bite_shift := 0.6
	var outer_tip := acos(-bite_shift / 2.0)
	var inner_tip := acos(bite_shift / 2.0)
	var points := PackedVector2Array()
	for k in 9:
		points.append(Vector2.from_angle(lerpf(-outer_tip, outer_tip, k / 8.0)) * radius)
	for k in range(1, 6):
		var angle := lerpf(inner_tip, -inner_tip, k / 6.0)
		points.append((Vector2.from_angle(angle) - Vector2(bite_shift, 0.0)) * radius)
	for i in points.size():
		points[i] = center + points[i].rotated(tilt)
	draw_colored_polygon(points, MOON_COLOR)

## The sun pokes up from behind the hills on the left as the moon goes down.
func _draw_sun(horizon_y: float) -> void:
	var sun_rise := clampf((_sky_progress - 0.3) / 0.7, 0.0, 1.0)
	if sun_rise <= 0.0:
		return
	var radius := size.y * 0.085
	var low := Vector2(size.x * 0.26, horizon_y + radius * 1.6)
	var high := Vector2(size.x * 0.32, size.y * 0.24)
	var center := low.lerp(high, sun_rise)
	var spin := _sky_progress * 0.6
	var rays := PackedVector2Array()
	for k in 16:
		var reach := radius * 1.45 if k % 2 == 0 else radius * 1.05
		rays.append(center + Vector2.from_angle(TAU * k / 16.0 + spin) * reach)
	draw_colored_polygon(rays, SUN_RAY_COLOR)
	var disc := PackedVector2Array()
	for k in 12:
		disc.append(center + Vector2.from_angle(TAU * k / 12.0) * radius)
	draw_colored_polygon(disc, SUN_COLOR)

## A low rolling hill in the distance and the junk heap's lumpy silhouette up
## close, both brightening with the sky. They reach well below the screen, for
## the view to start down on them.
func _draw_hills(horizon_y: float) -> void:
	var w := size.x
	var h := size.y
	var bottom := h * (1.0 + LOOK_DOWN_START)
	var hill := PackedVector2Array([
		Vector2(0.0, bottom), Vector2(0.0, horizon_y - h * 0.03), Vector2(w * 0.18, horizon_y - h * 0.08),
		Vector2(w * 0.42, horizon_y - h * 0.02), Vector2(w * 0.66, horizon_y - h * 0.09),
		Vector2(w * 0.86, horizon_y - h * 0.04), Vector2(w, horizon_y - h * 0.06), Vector2(w, bottom),
	])
	draw_colored_polygon(hill, HILL_NIGHT.lerp(HILL_DAY, _sky_progress))
	var heap := PackedVector2Array([
		Vector2(0.0, bottom), Vector2(0.0, horizon_y + h * 0.06), Vector2(w * 0.07, horizon_y + h * 0.01),
		Vector2(w * 0.13, horizon_y + h * 0.04), Vector2(w * 0.21, horizon_y - h * 0.03),
		Vector2(w * 0.30, horizon_y + h * 0.05), Vector2(w * 0.52, horizon_y + h * 0.08),
		Vector2(w * 0.63, horizon_y + h * 0.02), Vector2(w * 0.70, horizon_y + h * 0.05),
		Vector2(w * 0.84, horizon_y - h * 0.01), Vector2(w * 0.93, horizon_y + h * 0.06),
		Vector2(w, horizon_y + h * 0.03), Vector2(w, bottom),
	])
	draw_colored_polygon(heap, HEAP_NIGHT.lerp(HEAP_DAY, _sky_progress))
