class_name RaceTimerHud
extends Control
## Countdown readout for RaceController's max_duration, built the same way
## the open-world DigitalClock is: a ScrapBoard panel with a recessed dark
## "void" and hand-drawn seven-segment digits in the UI's accent yellow, so
## it reads as the same clock gadget instead of a bolted-on timer.
##
## RaceController drives this: it pushes the remaining seconds in every
## physics step via set_seconds_remaining(). Shows minutes:seconds.

const DIGIT_SIZE := Vector2(10.0, 17.0)
const DIGIT_GAP := 2.5
const SEGMENT_THICKNESS := 2.5
const COLON_GAP := 5.0
const BOARD_MARGIN := 4.0

const VOID_COLOR := UiPalette.VOID
const LIT_COLOR := UiPalette.ACCENT_YELLOW
const UNLIT_COLOR := Color(UiPalette.ACCENT_YELLOW, 0.15)
## Digits flip to this once time's running low — a wordless "wrap it up".
const WARN_COLOR := UiPalette.DANGER_RED
const WARN_THRESHOLD := 10.0

const BOARD_TILT_DEGREES := 1.5
const BOARD_JITTER_SEED := 4211

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

var _seconds_remaining: float = 0.0
var _board := ScrapBoard.new()

func _ready() -> void:
	_board.tilt_degrees = BOARD_TILT_DEGREES
	_board.jitter_seed = BOARD_JITTER_SEED
	_board.jitter = 2.0
	_board.skirt_height = 4.0

func set_seconds_remaining(seconds: float) -> void:
	_seconds_remaining = maxf(seconds, 0.0)
	queue_redraw()

func _draw() -> void:
	_board.draw(self, Rect2(Vector2.ZERO, size))

	var screen := Rect2(Vector2.ONE * BOARD_MARGIN, size - Vector2.ONE * BOARD_MARGIN * 2.0)
	draw_rect(screen, VOID_COLOR)

	var content_size := Vector2(4.0 * DIGIT_SIZE.x + 2.0 * DIGIT_GAP + COLON_GAP, DIGIT_SIZE.y)
	var origin := screen.position + (screen.size - content_size) / 2.0

	var whole := int(ceil(_seconds_remaining))
	var minutes := whole / 60
	var secs := whole % 60
	var lit_color := WARN_COLOR if _seconds_remaining <= WARN_THRESHOLD else LIT_COLOR

	var cursor := origin
	cursor = _draw_digit(cursor, minutes / 10, lit_color)
	cursor = _draw_digit(cursor, minutes % 10, lit_color)
	cursor = _draw_colon(cursor, lit_color)
	cursor = _draw_digit(cursor, secs / 10, lit_color)
	_draw_digit(cursor, secs % 10, lit_color)

func _draw_digit(origin: Vector2, digit: int, lit_color: Color) -> Vector2:
	var lit: Array = DIGIT_SEGMENTS.get(digit, [])
	for seg_id in DIGIT_SEGMENTS[8]:
		# "1" is drawn as one unbroken bar below, not segments b+c — at this
		# digit size the gap between them where "g" would sit reads as two
		# short stacked blocks, i.e. exactly what the colon looks like, not
		# a "1".
		if digit == 1 and (seg_id == "b" or seg_id == "c"):
			continue
		var color := lit_color if lit.has(seg_id) else UNLIT_COLOR
		draw_rect(_segment_rect(origin, seg_id), color)
	if digit == 1:
		var t := SEGMENT_THICKNESS
		draw_rect(Rect2(origin + Vector2(DIGIT_SIZE.x - t, t), Vector2(t, DIGIT_SIZE.y - 2.0 * t)), lit_color)
	return origin + Vector2(DIGIT_SIZE.x + DIGIT_GAP, 0.0)

func _draw_colon(origin: Vector2, lit_color: Color) -> Vector2:
	var dot_size := Vector2(SEGMENT_THICKNESS, SEGMENT_THICKNESS)
	var x := origin.x
	draw_rect(Rect2(Vector2(x, origin.y + DIGIT_SIZE.y * 0.28), dot_size), lit_color)
	draw_rect(Rect2(Vector2(x, origin.y + DIGIT_SIZE.y * 0.64), dot_size), lit_color)
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
