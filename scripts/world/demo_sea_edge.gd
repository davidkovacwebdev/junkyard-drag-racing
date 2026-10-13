class_name DemoSeaEdge
extends CanvasLayer
## The end of the demo's world, out at sea: with the Treasure Boat Engine
## the car can putter along the coast, but heading out to open water the
## screen fades to black (PlayerCar sets `depth`, 0 at the edge of the free
## strip to 1 at the line it can't cross) and a note says why.

const LAYER := 48
const TEXT := "This is a demo.\nFor the full game, visit Steam."
## The note fades in faster than the dark, so it's readable before it's black.
const TEXT_LEAD := 1.8

var depth := 0.0:
	set(value):
		depth = clampf(value, 0.0, 1.0)
		_refresh()

var _dark: ColorRect
var _label: Label

func _ready() -> void:
	layer = LAYER
	_dark = ColorRect.new()
	_dark.color = Color.BLACK
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)
	_label = Label.new()
	_label.text = TEXT
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_refresh()

func _refresh() -> void:
	if _dark == null:
		return
	visible = depth > 0.0
	_dark.color.a = depth
	_label.modulate.a = clampf(depth * TEXT_LEAD, 0.0, 1.0)
