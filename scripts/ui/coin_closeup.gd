class_name CoinCloseup
extends Control
## A close-up of treasure coins held up in a cutscene, big enough to read the
## engraving: "THIS IS NOT / PART OF THE / TRESURE" on the fakes, "TREASURE"
## on a real one (Grandpa's note says the real parts read "This is not part
## of the treasure."). `mark()` checks one: a fake gets a red bar under its
## typo and a hollow knock, a real one a yellow bar, a pop and a ting.
##
## Usage, from a Cutscene:
##   var closeup := CoinCloseup.open([CoinCloseup.FAKE, CoinCloseup.REAL])
##   closeup.mark(0)
##   closeup.close()
## It lives on its own layer under the letterbox bars and subtitles, and
## snaps straight to the end state while the cutscene is being skipped.

const FAKE := "TRESURE"
const REAL := "TREASURE"
const LAYER := 49
## The coins sit in a row a little above the middle of the screen, clear of
## the subtitle.
const ROW_HEIGHT := 0.42
const RADIUS := 86.0
const GAP := 34.0
const LINES := ["THIS IS NOT", "PART OF THE"]
const FONT_SIZE := 18
const LINE_STEP := 23.0
## The world dims behind the coins while they're up.
const DIM := Color(0, 0, 0, 0.4)
const BAR_SIZE := Vector2(92.0, 7.0)
const POP_SPEED := 9.0
const STAGGER := 0.12
const MARK_POP := 0.16
## The same nickel greys as the Old Nickel icon.
const COIN := Color(0.7, 0.71, 0.7, 1)
const COIN_SHADE := Color(0.55, 0.56, 0.55, 1)
const ENGRAVING := Color(0.4, 0.41, 0.4, 1)

var _words: Array = []
## Per coin: how far it has popped in (0-1), and whether it's been checked.
var _shown: Array[float] = []
var _marked: Array[bool] = []
var _pop: Array[float] = []
var _time: float = 0.0
var _closing: bool = false

## Puts the coins up, one per word in `words` (FAKE or REAL), with a clink.
static func open(words: Array) -> CoinCloseup:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	var closeup := CoinCloseup.new()
	closeup._words = words.duplicate()
	for i in words.size():
		closeup._shown.append(0.0)
		closeup._marked.append(false)
		closeup._pop.append(0.0)
	closeup.set_anchors_preset(Control.PRESET_FULL_RECT)
	closeup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(closeup)
	Cutscenes.add_child(layer)
	Cutscenes.sound(&"coin_clink", -6.0)
	return closeup

## Checks coin `index`: underlines its last word, red for a fake, yellow for
## the real thing.
func mark(index: int) -> void:
	if index < 0 or index >= _words.size() or _marked[index]:
		return
	_marked[index] = true
	_pop[index] = 1.0
	if _words[index] == REAL:
		Cutscenes.sound(&"wink_ting", -6.0)
	else:
		Cutscenes.sound(&"fake_gold_knock", -10.0)

func close() -> void:
	if _closing:
		return
	_closing = true
	if Cutscenes.is_skipping():
		get_parent().queue_free()

func _process(delta: float) -> void:
	_time += delta
	var skipping := Cutscenes.is_skipping()
	var done := true
	for i in _shown.size():
		var target := 0.0 if _closing else (1.0 if _time >= i * STAGGER else 0.0)
		_shown[i] = target if skipping else move_toward(_shown[i], target, delta * POP_SPEED * 0.5)
		_pop[i] = maxf(0.0, _pop[i] - delta * 4.0)
		done = done and _shown[i] <= 0.0
	if _closing and done:
		get_parent().queue_free()
	queue_redraw()

func _draw() -> void:
	var count := _words.size()
	if count == 0:
		return
	var dim := DIM
	dim.a *= clampf(_shown.max(), 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), dim)
	var font := get_theme_default_font()
	var row_width := count * RADIUS * 2.0 + (count - 1) * GAP
	var first := Vector2((size.x - row_width) * 0.5 + RADIUS, size.y * ROW_HEIGHT)
	for i in count:
		var shown := _shown[i]
		if shown <= 0.0:
			continue
		# A little overshoot as it pops in, a bump when it's checked.
		var scale_now := _back_out(shown) * (1.0 + MARK_POP * _pop[i])
		var tilt: float = [-0.06, 0.05, -0.03, 0.07][i % 4]
		draw_set_transform(first + Vector2(i * (RADIUS * 2.0 + GAP), 0.0), tilt, Vector2.ONE * scale_now)
		draw_colored_polygon(_octagon(RADIUS), COIN)
		draw_colored_polygon(_shade(RADIUS), COIN_SHADE)
		var lines: Array = LINES + [_words[i]]
		for l in lines.size():
			var text: String = lines[l]
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			var y := (l - 1) * LINE_STEP + FONT_SIZE * 0.35
			draw_string(font, Vector2(-width * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ENGRAVING)
		if _marked[i]:
			var bar_y := LINE_STEP + FONT_SIZE * 0.35 + 6.0
			var color := UiPalette.ACCENT_YELLOW if _words[i] == REAL else UiPalette.DANGER_RED
			draw_rect(Rect2(Vector2(-BAR_SIZE.x * 0.5, bar_y), BAR_SIZE), color)
	draw_set_transform(Vector2.ZERO)

## The same squared-off octagon as the Old Nickel icon, at `r`.
static func _octagon(r: float) -> PackedVector2Array:
	var c := r * 0.43
	return PackedVector2Array([Vector2(-c, -r), Vector2(c, -r), Vector2(r, -c), Vector2(r, c),
			Vector2(c, r), Vector2(-c, r), Vector2(-r, c), Vector2(-r, -c)])

## Its right-hand shade strip, like the icon's.
static func _shade(r: float) -> PackedVector2Array:
	var c := r * 0.43
	var k := r * 0.22
	return PackedVector2Array([Vector2(c, -r), Vector2(r, -c), Vector2(r, c), Vector2(c, r),
			Vector2(c - k, r), Vector2(r - k * 1.6, c), Vector2(r - k * 1.6, -c), Vector2(c - k, -r)])

static func _back_out(t: float) -> float:
	var s := 1.7
	var u := t - 1.0
	return 1.0 + (s + 1.0) * u * u * u + s * u * u
