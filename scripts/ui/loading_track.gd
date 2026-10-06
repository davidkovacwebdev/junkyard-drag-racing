class_name LoadingTrack
extends Control
## The loading board's progress readout: a row of uneven blocks that fill up
## yellow, with a tyre spinning its wheels and hopping along at the head of the
## fill. `progress` is where the fill should be; the drawn fill eases after it so
## jumps in the real progress still read as the tyre rolling forward.

const BLOCK_COUNT := 8
const BLOCK_GAP := 6.0
const BLOCK_HEIGHT := 16.0
const TYRE_RADIUS := 17.0
const HUB_RADIUS := 7.0
const HOP_HEIGHT := 7.0
const HOP_SPEED := 9.0
const SPIN_SPEED := 9.0
const FILL_SPEED := 3.5
const TYRE_COLOR := Color(0.20, 0.19, 0.18)

## 0..1, set by whoever is loading.
var progress: float = 0.0

var _shown_progress: float = 0.0
var _time: float = 0.0
var _block_heights := PackedFloat32Array()

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	for i in BLOCK_COUNT:
		_block_heights.append(BLOCK_HEIGHT + rng.randf_range(-3.0, 3.0))

## Snap the fill back to empty for the next load.
func reset() -> void:
	progress = 0.0
	_shown_progress = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_shown_progress = move_toward(_shown_progress, clampf(progress, 0.0, 1.0), FILL_SPEED * delta)
	queue_redraw()

func _draw() -> void:
	var block_width := (size.x - BLOCK_GAP * (BLOCK_COUNT - 1)) / BLOCK_COUNT
	var floor_y := size.y
	var filled := _shown_progress * BLOCK_COUNT
	for i in BLOCK_COUNT:
		var x := i * (block_width + BLOCK_GAP)
		var color := UiPalette.ACCENT_YELLOW if i < roundi(filled) else UiPalette.STAT_EMPTY
		draw_rect(Rect2(x, floor_y - _block_heights[i], block_width, _block_heights[i]), color)

	var head_x := clampf(_shown_progress * size.x, TYRE_RADIUS, size.x - TYRE_RADIUS)
	var block_index := clampi(int(head_x / (block_width + BLOCK_GAP)), 0, BLOCK_COUNT - 1)
	var ground := floor_y - _block_heights[block_index]
	var hop := absf(sin(_time * HOP_SPEED)) * HOP_HEIGHT
	var centre := Vector2(head_x, ground - TYRE_RADIUS - hop)
	var spin := _time * SPIN_SPEED

	var shadow_width := TYRE_RADIUS * (1.0 - hop / (HOP_HEIGHT * 3.0))
	draw_colored_polygon(FlatProps.octagon(Vector2(head_x, ground - 2.0), shadow_width, 4.0), UiPalette.SHADOW)
	draw_colored_polygon(_ngon(centre, TYRE_RADIUS, 12, spin), TYRE_COLOR)
	draw_colored_polygon(_ngon(centre, HUB_RADIUS, 6, spin), UiPalette.STEEL_BASE)
	draw_colored_polygon(_ngon(centre + Vector2(HUB_RADIUS * 0.45, 0.0).rotated(spin), 2.5, 4, spin), UiPalette.STEEL_DARK)

static func _ngon(centre: Vector2, radius: float, sides: int, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		points.append(centre + Vector2(radius, 0.0).rotated(angle + TAU * i / sides))
	return points
