class_name DigitalClock
extends Control
## Small retro LCD clock, housed in the same brushed-steel style as the
## minimap's rim (see Minimap._draw) so the two read as one instrument
## mounted on the same dash rather than two unrelated HUD widgets. Meant
## to sit flush above the minimap in the scene, sharing its width.
##
## Digits are hand-drawn seven-segment strokes (no font involved) reading
## the in-game hour off DayNightCycle, HH:MM 24-hour.

const DIGIT_SIZE := Vector2(12.0, 20.0)
const DIGIT_GAP := 3.0
const SEGMENT_THICKNESS := 3.0
const COLON_GAP := 6.0
## Empty space between the digits and the LCD screen's own edge.
const SCREEN_PADDING := 8.0

## Steel housing around the LCD screen, matching Minimap's rim palette.
const BEZEL_MARGIN := 5.0
const RIVET_INSET := 4.0
const RIVET_SIZE := 1.3

const LCD_COLOR := Color(0.05, 0.04, 0.04, 1)
const LIT_COLOR := Color(1.0, 0.15, 0.08, 1)
const UNLIT_COLOR := Color(1.0, 0.15, 0.08, 0.12)

## Standard seven-segment layout, keyed a (top) round to g (middle).
const DIGIT_SEGMENTS := {
	0: ["a", "b", "c", "d", "e", "f"],
	1: ["b", "c"],
	2: ["a", "b", "g", "e", "d"],
	3: ["a", "b", "g", "c", "d"],
	4: ["f", "g", "b", "c"],
	5: ["a", "f", "g", "c", "d"],
	6: ["a", "f", "g", "e", "c", "d"],
	7: ["a", "b", "c"],
	8: ["a", "b", "c", "d", "e", "f", "g"],
	9: ["a", "b", "c", "d", "f", "g"],
}

## Real-world seconds, not in-game ones — a blink tied to DayNightCycle's
## sped-up minutes would flicker many times a second.
var _blink_time: float = 0.0

func _process(delta: float) -> void:
	_blink_time = fmod(_blink_time + delta, 1.0)
	queue_redraw()

func _draw() -> void:
	_draw_bezel()

	var screen := Rect2(Vector2.ONE * BEZEL_MARGIN, size - Vector2.ONE * BEZEL_MARGIN * 2.0)
	draw_rect(screen, LCD_COLOR)

	var content_size := Vector2(4.0 * DIGIT_SIZE.x + 2.0 * DIGIT_GAP + COLON_GAP, DIGIT_SIZE.y)
	var origin := screen.position + (screen.size - content_size) / 2.0

	var hour := int(DayNightCycle.get_hour())
	var minute := int(fmod(DayNightCycle.get_hour(), 1.0) * 60.0)

	var cursor := origin
	cursor = _draw_digit(cursor, hour / 10)
	cursor = _draw_digit(cursor, hour % 10)
	cursor = _draw_colon(cursor)
	cursor = _draw_digit(cursor, minute / 10)
	_draw_digit(cursor, minute % 10)

## Brushed-steel housing: a flat plate with a corner rivet each side, the
## same shorthand Minimap uses for its rim rather than a full match of its
## round bevel (this panel's rectangular, so that geometry doesn't carry
## over) — enough to read as the same dashboard hardware.
func _draw_bezel() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.STEEL_SHADE)
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.STEEL_DARK, false, 2.0)
	for corner in [Vector2(RIVET_INSET, RIVET_INSET), Vector2(size.x - RIVET_INSET, RIVET_INSET),
			Vector2(RIVET_INSET, size.y - RIVET_INSET), Vector2(size.x - RIVET_INSET, size.y - RIVET_INSET)]:
		draw_colored_polygon(PackedVector2Array([
			corner + Vector2(-RIVET_SIZE, -RIVET_SIZE), corner + Vector2(RIVET_SIZE, -RIVET_SIZE),
			corner + Vector2(RIVET_SIZE, RIVET_SIZE), corner + Vector2(-RIVET_SIZE, RIVET_SIZE),
		]), UiPalette.STEEL_DARK)

func _draw_digit(origin: Vector2, digit: int) -> Vector2:
	var lit: Array = DIGIT_SEGMENTS.get(digit, [])
	for seg_id in DIGIT_SEGMENTS[8]:
		# "1" is drawn as one unbroken bar below, not segments b+c — at this
		# digit size the gap between them where "g" would sit reads as two
		# short stacked blocks, i.e. exactly what the colon looks like, not
		# a "1".
		if digit == 1 and (seg_id == "b" or seg_id == "c"):
			continue
		var color := LIT_COLOR if lit.has(seg_id) else UNLIT_COLOR
		draw_rect(_segment_rect(origin, seg_id), color)
	if digit == 1:
		var t := SEGMENT_THICKNESS
		draw_rect(Rect2(origin + Vector2(DIGIT_SIZE.x - t, t), Vector2(t, DIGIT_SIZE.y - 2.0 * t)), LIT_COLOR)
	return origin + Vector2(DIGIT_SIZE.x + DIGIT_GAP, 0.0)

## The colon blinks on the real-world second, same rhythm a bedside clock
## keeps, regardless of how fast the in-game hour is actually moving.
func _draw_colon(origin: Vector2) -> Vector2:
	if _blink_time < 0.5:
		var dot_size := Vector2(SEGMENT_THICKNESS, SEGMENT_THICKNESS)
		var x := origin.x
		draw_rect(Rect2(Vector2(x, origin.y + DIGIT_SIZE.y * 0.28), dot_size), LIT_COLOR)
		draw_rect(Rect2(Vector2(x, origin.y + DIGIT_SIZE.y * 0.64), dot_size), LIT_COLOR)
	return origin + Vector2(COLON_GAP, 0.0)

## One segment's rect within a digit box anchored at `origin`. Horizontal
## bars (a/g/d) run the digit's full width; vertical ones (b/c/e/f) sit
## flush to whichever side and span a bit over a third of the digit's
## height each — tall strokes, not the near-square blocks a smaller digit
## used to draw, which at a glance read as a second colon rather than "1".
func _segment_rect(origin: Vector2, seg_id: String) -> Rect2:
	var w := DIGIT_SIZE.x
	var h := DIGIT_SIZE.y
	var t := SEGMENT_THICKNESS
	var half_h := (h - t) / 2.0
	match seg_id:
		"a":
			return Rect2(origin + Vector2(0.0, 0.0), Vector2(w, t))
		"g":
			return Rect2(origin + Vector2(0.0, half_h), Vector2(w, t))
		"d":
			return Rect2(origin + Vector2(0.0, h - t), Vector2(w, t))
		"f":
			return Rect2(origin + Vector2(0.0, t), Vector2(t, half_h - t))
		"b":
			return Rect2(origin + Vector2(w - t, t), Vector2(t, half_h - t))
		"e":
			return Rect2(origin + Vector2(0.0, half_h + t), Vector2(t, half_h - t))
		"c":
			return Rect2(origin + Vector2(w - t, half_h + t), Vector2(t, half_h - t))
	return Rect2()
