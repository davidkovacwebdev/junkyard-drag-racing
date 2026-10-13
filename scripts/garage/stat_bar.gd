@tool
class_name StatBar
extends Control
## 5-block rating bar: separate blocks with small gaps and slightly uneven
## heights, filled in yellow up to the rating. Used for a part's Durability /
## Speed / Mass at a glance. A fractional rating fills the last block part way,
## so small changes (the garage's whole-car stats) still show.

const BLOCK_COUNT := 5
const BLOCK_WIDTH := 15.0
const BLOCK_GAP := 3.0
const BLOCK_HEIGHT := 9.0
## Per-block height wobble, so the row looks hand-cut.
const HEIGHT_JITTER := [0.0, -2.0, 1.0, -1.0, 2.0]

var _rating: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(BLOCK_COUNT * (BLOCK_WIDTH + BLOCK_GAP), BLOCK_HEIGHT + 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_rating(rating: float) -> void:
	_rating = clampf(rating, 0.0, BLOCK_COUNT)
	queue_redraw()

## A 0..1 stat position as blocks: even the worst part gets one, so an empty
## bar always means "nothing there".
static func rating_for(fraction: float) -> int:
	return roundi(exact_rating_for(fraction))

## rating_for() without the rounding, for a bar that fills part blocks.
static func exact_rating_for(fraction: float) -> float:
	return 1.0 + clampf(fraction, 0.0, 1.0) * (BLOCK_COUNT - 1)

func _draw() -> void:
	var bottom := (size.y + BLOCK_HEIGHT) / 2.0
	for i in BLOCK_COUNT:
		var height: float = BLOCK_HEIGHT + HEIGHT_JITTER[i]
		var left := i * (BLOCK_WIDTH + BLOCK_GAP)
		var block := Rect2(left, bottom - height, BLOCK_WIDTH, height)
		var filled := clampf(_rating - i, 0.0, 1.0)
		if filled < 1.0:
			draw_rect(block, UiPalette.STAT_EMPTY)
		if filled > 0.0:
			draw_rect(Rect2(block.position, Vector2(BLOCK_WIDTH * filled, height)), UiPalette.ACCENT_YELLOW)
