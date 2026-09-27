class_name DigitalClock
extends Control
## Small digital clock, built the same way every other panel in the game
## is: a ScrapBoard (the same salvaged-wood board the garage and menus
## use) with a dark recessed "void" cut into it for the display, and
## flat seven-segment digits lit in the UI's accent yellow — the same
## yellow the road's dashed centre line uses, so the readout ties back
## into the game's own world instead of reading as an unrelated gadget.
##
## Digits are hand-drawn strokes (no font involved), reading the in-game
## hour off DayNightCycle, HH:MM 24-hour.

const DIGIT_SIZE := Vector2(10.0, 17.0)
const DIGIT_GAP := 2.5
const SEGMENT_THICKNESS := 2.5
const COLON_GAP := 5.0
## Empty space between the digits and the recessed screen's own edge, and
## between the screen and the board's outer edge.
const SCREEN_PADDING := 5.0
const BOARD_MARGIN := 4.0

const VOID_COLOR := UiPalette.VOID
const LIT_COLOR := UiPalette.ACCENT_YELLOW
const UNLIT_COLOR := Color(UiPalette.ACCENT_YELLOW, 0.15)

const BOARD_TILT_DEGREES := -1.5
const BOARD_JITTER_SEED := 7733

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
var _board := ScrapBoard.new()

func _ready() -> void:
	_board.tilt_degrees = BOARD_TILT_DEGREES
	_board.jitter_seed = BOARD_JITTER_SEED
	_board.jitter = 2.0
	_board.skirt_height = 4.0

func _process(delta: float) -> void:
	_blink_time = fmod(_blink_time + delta, 1.0)
	queue_redraw()

func _draw() -> void:
	_board.draw(self, Rect2(Vector2.ZERO, size))

	var screen := Rect2(Vector2.ONE * BOARD_MARGIN, size - Vector2.ONE * BOARD_MARGIN * 2.0)
	draw_rect(screen, VOID_COLOR)

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
## height each — tall strokes, not near-square blocks that would read as
## a second colon rather than a stroke.
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
