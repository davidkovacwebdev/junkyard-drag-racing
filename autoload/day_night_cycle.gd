extends Node
## Tracks in-game time (autoload singleton "DayNightCycle"). A day lasts
## DAY_LENGTH seconds, the last NIGHT_LENGTH of which are night.
## get_night_factor() blends smoothly from 0 (day) to 1
## (night) across a TRANSITION-second window straddling both the start and
## the end of night — 1 minute before the boundary and 1 minute after it —
## so a screen-space shader (see NightOverlay) can fade in/out instead of
## snapping the instant the clock crosses it.

const DAY_LENGTH := 720.0   ## 12 minutes.
const NIGHT_LENGTH := 240.0 ## 4 minutes, at the end of the day.
const TRANSITION := 60.0    ## 1 minute either side of each night boundary.
const NIGHT_START := DAY_LENGTH - NIGHT_LENGTH ## 480s into the day.

## Testing aid: hold K to fast-forward the clock 24x so a full day/night
## cycle takes 30 seconds instead of 12 minutes.
const DEBUG_FAST_FORWARD_KEY := KEY_K
const DEBUG_FAST_FORWARD_SCALE := 24.0

## Every new day starts at 8 AM rather than midnight.
const START_TIME := (DAY_LENGTH / 24.0) * 8.0

var day: int = 1
var time_of_day: float = START_TIME ## Seconds into the current day, [0, DAY_LENGTH).

func _process(delta: float) -> void:
	var scale := DEBUG_FAST_FORWARD_SCALE if Input.is_physical_key_pressed(DEBUG_FAST_FORWARD_KEY) else 1.0
	time_of_day += delta * scale
	if time_of_day >= DAY_LENGTH:
		time_of_day -= DAY_LENGTH
		day += 1

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
	while time_of_day >= DAY_LENGTH:
		time_of_day -= DAY_LENGTH
		day += 1

## 0 = full day, 1 = full night, ramping linearly across the two
## TRANSITION-second windows centred on dusk (NIGHT_START) and dawn
## (DAY_LENGTH, wrapping around to 0).
func get_night_factor() -> float:
	var t := time_of_day
	var dusk_start := NIGHT_START - TRANSITION
	var dusk_end := NIGHT_START + TRANSITION
	var dawn_start := DAY_LENGTH - TRANSITION
	if t < TRANSITION:
		# Tail of the dawn ramp, wrapped over from the end of the previous day.
		return 1.0 - (t + TRANSITION) / (TRANSITION * 2.0)
	elif t < dusk_start:
		return 0.0
	elif t < dusk_end:
		return (t - dusk_start) / (TRANSITION * 2.0)
	elif t < dawn_start:
		return 1.0
	else:
		return 1.0 - (t - dawn_start) / (TRANSITION * 2.0)
