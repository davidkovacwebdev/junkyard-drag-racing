@tool
class_name StatBar
extends Control
## 5-block rating bar: separate blocks with small gaps and slightly uneven
## heights, filled in yellow up to the rating. Used for a part's Durability /
## Speed / Mass at a glance.

const BLOCK_COUNT := 5
const BLOCK_WIDTH := 15.0
const BLOCK_GAP := 3.0
const BLOCK_HEIGHT := 9.0
## Per-block height wobble, so the row looks hand-cut.
const HEIGHT_JITTER := [0.0, -2.0, 1.0, -1.0, 2.0]

var _rating: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(BLOCK_COUNT * (BLOCK_WIDTH + BLOCK_GAP), BLOCK_HEIGHT + 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_rating(rating: int) -> void:
	_rating = clampi(rating, 0, BLOCK_COUNT)
	queue_redraw()

func _draw() -> void:
	var bottom := (size.y + BLOCK_HEIGHT) / 2.0
	for i in BLOCK_COUNT:
		var height: float = BLOCK_HEIGHT + HEIGHT_JITTER[i]
		var left := i * (BLOCK_WIDTH + BLOCK_GAP)
		var color := UiPalette.ACCENT_YELLOW if i < _rating else UiPalette.STAT_EMPTY
		draw_rect(Rect2(left, bottom - height, BLOCK_WIDTH, height), color)
