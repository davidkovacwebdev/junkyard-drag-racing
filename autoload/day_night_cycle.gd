extends Node
## Tracks in-game time (autoload singleton "DayNightCycle"). A day lasts
## DAY_LENGTH seconds, mapped onto a 24-hour clock. Night runs from
## NIGHT_START_HOUR (9 PM) to NIGHT_END_HOUR (8 AM) — that span straddles
## midnight, so unlike a simpler "last N seconds of the day" scheme, night
## isn't at the day's edges; the day/time_of_day rollover point (24:00 ->
## 0:00) instead falls in the *middle* of the full-night stretch.
## get_night_factor() blends smoothly from 0 (day) to 1 (night) across a
## TRANSITION-second window centred on each boundary — 1 minute before it
## and 1 minute after — so a screen-space shader (see NightOverlay) can
## fade in/out instead of snapping the instant the clock crosses it.

const DAY_LENGTH := 720.0   ## 12 minutes = 24 in-game hours.
const SECONDS_PER_HOUR := DAY_LENGTH / 24.0
const TRANSITION := 60.0    ## 1 minute either side of each night boundary.
const NIGHT_START := 21.0 * SECONDS_PER_HOUR ## 9 PM.
const NIGHT_END := 8.0 * SECONDS_PER_HOUR    ## 8 AM, the following morning.

## Testing aid: hold K to fast-forward the clock 24x so a full day/night
## cycle takes 30 seconds instead of 12 minutes.
const DEBUG_FAST_FORWARD_KEY := KEY_K
const DEBUG_FAST_FORWARD_SCALE := 24.0

## Every new day starts at 8 AM (right as night ends) rather than midnight.
const START_TIME := NIGHT_END

## Fired the moment the calendar rolls over, so the world can restock itself:
## roadside bins ask whether their patch has come back full (see WorldState).
## Not fired by `reset()`, which is a fresh start rather than a new day.
signal day_changed(day: int)

var day: int = 1
var time_of_day: float = START_TIME ## Seconds into the current day, [0, DAY_LENGTH).

func _process(delta: float) -> void:
	var scale := DEBUG_FAST_FORWARD_SCALE if Input.is_physical_key_pressed(DEBUG_FAST_FORWARD_KEY) else 1.0
	time_of_day += delta * scale
	if time_of_day >= DAY_LENGTH:
		time_of_day -= DAY_LENGTH
		day += 1
		day_changed.emit(day)

## Called on New Game — Continue restores day/time_of_day from SaveSystem
## instead, never through here.
func reset() -> void:
	day = 1
	time_of_day = START_TIME

## Jumps the clock forward without waiting — e.g. swapping a part in the
## garage or starting a race both cost story time on top of whatever's
## ticked by naturally. A day is 24 in-game hours over DAY_LENGTH seconds.
func advance_hours(hours: float) -> void:
	advance_seconds(hours * (DAY_LENGTH / 24.0))

func advance_seconds(seconds: float) -> void:
	time_of_day += seconds
	var rolled := false
	while time_of_day >= DAY_LENGTH:
		time_of_day -= DAY_LENGTH
		day += 1
		rolled = true
	if rolled:
		day_changed.emit(day)

## Current hour of day, [0.0, 24.0) — plain clock time, not the
## dusk/dawn-blended get_night_factor() below. For anything that opens
## and closes on a fixed schedule (the drag strip, say) rather than
## fading with the light.
func get_hour() -> float:
	return time_of_day / SECONDS_PER_HOUR

## 0 = full day, 1 = full night, ramping linearly across the two
## TRANSITION-second windows centred on dusk (NIGHT_START) and dawn
## (NIGHT_END). Both windows sit comfortably clear of the 0/DAY_LENGTH
## rollover point, so — unlike the old scheme — this never needs to
## handle a transition wrapping across midnight itself.
func get_night_factor() -> float:
	var t := time_of_day
	var dusk_start := NIGHT_START - TRANSITION
	var dusk_end := NIGHT_START + TRANSITION
	var dawn_start := NIGHT_END - TRANSITION
	var dawn_end := NIGHT_END + TRANSITION
	if t < dawn_start or t >= dusk_end:
		return 1.0
	elif t < dawn_end:
		return 1.0 - (t - dawn_start) / (TRANSITION * 2.0)
	elif t < dusk_start:
		return 0.0
	else:
		return (t - dusk_start) / (TRANSITION * 2.0)
