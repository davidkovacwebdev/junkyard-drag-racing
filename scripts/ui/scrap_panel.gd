@tool
class_name ScrapPanel
extends Control
## A salvaged board behind other UI — title plates, dialog backs, sign posts.
## Children (labels etc.) sit on top of it untilted; only the board is tilted.

@export var body_color := UiPalette.SURFACE_BASE:
	set(value):
		body_color = value
		queue_redraw()
@export var shade_color := UiPalette.SURFACE_SHADE:
	set(value):
		shade_color = value
		queue_redraw()
@export var skirt_color := UiPalette.SURFACE_DARK:
	set(value):
		skirt_color = value
		queue_redraw()
@export_range(-6.0, 6.0) var tilt_degrees: float = 0.0:
	set(value):
		tilt_degrees = value
		queue_redraw()
@export var jitter_seed: int = 0:
	set(value):
		jitter_seed = value
		queue_redraw()
@export var nails: bool = true:
	set(value):
		nails = value
		queue_redraw()

var _board := ScrapBoard.new()

func _draw() -> void:
	_board.body_color = body_color
	_board.shade_color = shade_color
	_board.skirt_color = skirt_color
	_board.tilt_degrees = tilt_degrees
	_board.jitter_seed = jitter_seed
	_board.nails = nails
	_board.draw(self, Rect2(Vector2.ZERO, size))
