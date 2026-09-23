extends Node
## Tracks whether it's raining (autoload singleton "Weather"), and how soaked
## the world has become because of it.
##
## Rain comes and goes on a schedule derived from the in-game calendar: each
## day rolls one or two showers from a fixed seed, and `wetness` climbs while
## one is falling and dries off afterwards. Nothing else decides anything —
## `wetness` and `rain_intensity` are the whole interface:
##
## - `PuddleField` fades its puddles in with `get_wetness()`,
## - `RainLayer` sets its alpha from `get_rain_intensity()`,
## - `PlayerCar` loses grip while it's standing in a puddle.
##
## The schedule is a **pure function of the day number**, so the same day
## always has the same weather. That's what lets rain survive a map reload
## (walking out of the garage) without anything having to be saved, exactly
## like the roadside trash's restock day.
##
## No save data: `wetness` lives in this autoload, which outlives every scene
## change, so it persists for the session on its own.

## Fired when rain starts/stops falling (a schedule transition, not every
## frame). Nothing reads these yet — they're here so a future rain-sound or
## weather UI has something to hang off.
signal rain_started()
signal rain_stopped()

## Seed for the daily rain roll. Change it for a different climate.
const SCHEDULE_SEED := 8151
## Chance any given day has rain at all.
const RAIN_DAY_CHANCE := 0.55
## Chance a rainy day gets a second, separate shower.
const SECOND_SHOWER_CHANCE := 0.3
## A shower's length, in in-game hours.
const SHOWER_MIN_HOURS := 1.0
const SHOWER_MAX_HOURS := 3.0

## Seconds for the visible rain to fade in or out, so a shower arrives as a
## building drizzle rather than a hard cut.
const FADE_TIME := 2.0
## How long standing rain takes to soak the ground (rain -> puddles), and how
## long the ground then takes to dry out. Drying is much slower than soaking,
## so puddles linger a while after the shower passes.
const SOAK_SECONDS := 8.0
const DRY_SECONDS := 45.0

## Testing/authoring aid: hold J to cycle the weather auto -> raining -> dry.
## Same idea as DayNightCycle's K fast-forward.
const DEBUG_TOGGLE_KEY := KEY_J

## 0 = bone dry, 1 = soaked through. Drives puddle opacity and car grip.
var wetness: float = 0.0
## 0 = no rain falling, 1 = full shower. Drives the rain layer's alpha.
var rain_intensity: float = 0.0

## Showers for the current day, as Vector2(start_hour, length_hours).
var _windows: Array[Vector2] = []
## Manual override: -1 = weather decides, 0 = forced dry, 1 = forced rain.
var _override: int = -1
var _toggle_held: bool = false
var _was_raining: bool = false

func _ready() -> void:
	DayNightCycle.day_changed.connect(_on_day_changed)
	_schedule(DayNightCycle.day)
	_was_raining = _is_raining_now()

func _process(delta: float) -> void:
	_handle_debug_toggle()

	var raining := _is_raining_now()
	if raining != _was_raining:
		_was_raining = raining
		if raining:
			rain_started.emit()
		else:
			rain_stopped.emit()

	rain_intensity = move_toward(rain_intensity, 1.0 if raining else 0.0, delta / FADE_TIME)

	# Soaking scales with how hard it's coming down, so the ground barely
	# dampens during the two-second fade-in; drying is a slow constant.
	if rain_intensity > 0.05:
		wetness = minf(1.0, wetness + delta / SOAK_SECONDS * rain_intensity)
	else:
		wetness = maxf(0.0, wetness - delta / DRY_SECONDS)

## 0..1, how hard it's raining right now.
func get_rain_intensity() -> float:
	return rain_intensity

## 0..1, how wet the ground has become.
func get_wetness() -> float:
	return wetness

func is_raining() -> bool:
	return rain_intensity > 0.05

## Whether there's enough standing water to read as a wet road — the threshold
## the puddle field fades in past.
func is_wet() -> bool:
	return wetness > 0.15

## Force the weather (for tests or the debug key). -1 lets the schedule decide,
## 0 forces it dry, 1 forces rain. The visible fade and the soak/dry ramp still
## run, so forcing rain doesn't teleport puddles onto the road.
func force_rain(mode: int) -> void:
	_override = clampi(mode, -1, 1)

## The day's showers, as Vector2(start_hour, length_hours) pairs. Handy for a
## forecast UI, and used by the smoke test.
func get_showers() -> Array[Vector2]:
	return _windows.duplicate()

## Advance straight to a given hour of the current day — the smoke test uses
## this to land inside a known shower instead of waiting for one.
func get_shower_hour(index: int) -> float:
	if index < 0 or index >= _windows.size():
		return -1.0
	var window := _windows[index]
	return window.x + window.y * 0.5

func _on_day_changed(day: int) -> void:
	_schedule(day)

## Roll the day's showers. Seeded on the day number alone, so the same day
## always rains the same way, whichever scene asks.
func _schedule(day: int) -> void:
	_windows.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SCHEDULE_SEED + day
	if rng.randf() >= RAIN_DAY_CHANCE:
		return
	_windows.append(_roll_shower(rng))
	if rng.randf() < SECOND_SHOWER_CHANCE:
		_windows.append(_roll_shower(rng))

## One shower, kept wholly inside the day (never wrapping midnight) so a
## forecast reads as a plain start/end pair.
func _roll_shower(rng: RandomNumberGenerator) -> Vector2:
	var length := rng.randf_range(SHOWER_MIN_HOURS, SHOWER_MAX_HOURS)
	var start := rng.randf_range(0.0, 24.0 - length)
	return Vector2(start, length)

func _is_raining_now() -> bool:
	if _override >= 0:
		return _override == 1
	return _is_raining_at(DayNightCycle.get_hour())

func _is_raining_at(hour: float) -> bool:
	for window in _windows:
		# fposmod rather than a plain compare, so a shower placed by hand (or
		# a future one that wraps midnight) still resolves correctly.
		if fposmod(hour - window.x, 24.0) < window.y:
			return true
	return false

## Hold J to step the override auto -> forced dry -> forced rain -> auto.
func _handle_debug_toggle() -> void:
	var held := Input.is_physical_key_pressed(DEBUG_TOGGLE_KEY)
	if held and not _toggle_held:
		_override = ((_override + 1) + 1) % 3 - 1
	_toggle_held = held
