class_name AnalogClock
extends Control
## Minimal analogue clock: no face, no numbers, just an hour hand and a
## minute hand pivoting around the same point, driven by DayNightCycle.
## Same convention a real 12-hour clock face uses: the hour hand sweeps
## twice per in-game day (once per 12 in-game hours), the minute hand
## sweeps once per in-game hour.

const HOUR_HAND_LENGTH := 16.0
const MINUTE_HAND_LENGTH := 24.0
const HOUR_HAND_WIDTH := 4.0
const MINUTE_HAND_WIDTH := 2.0
const HAND_COLOR := Color(1, 1, 1, 1)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var half_day := DayNightCycle.DAY_LENGTH / 2.0
	var hour_step := DayNightCycle.DAY_LENGTH / 24.0
	var hour_hand_fraction := fmod(DayNightCycle.time_of_day, half_day) / half_day
	var minute_hand_fraction := fmod(DayNightCycle.time_of_day, hour_step) / hour_step
	_draw_hand(center, hour_hand_fraction, HOUR_HAND_LENGTH, HOUR_HAND_WIDTH)
	_draw_hand(center, minute_hand_fraction, MINUTE_HAND_LENGTH, MINUTE_HAND_WIDTH)

func _draw_hand(center: Vector2, fraction: float, length: float, width: float) -> void:
	var tip := center + Vector2(0.0, -length).rotated(fraction * TAU)
	draw_line(center, tip, HAND_COLOR, width)
