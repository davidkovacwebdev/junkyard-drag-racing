class_name SpeechScroll
extends ScrollContainer
## Keeps a speech line inside its board however long it runs: the label sits
## in a scroll box the size it used to be, and while the line types out
## (SpeechPlayer's visible characters) the box follows it down. The mouse
## wheel scrolls back up. No scrollbar is drawn; short lines sit where they
## always did.
##
## Usage: `SpeechScroll.wrap(label)` once, after the label is in the tree.

var _label: Label
var _last_ratio := -1.0

## Moves `label` into a SpeechScroll that takes over its place and layout.
static func wrap(label: Label) -> SpeechScroll:
	var scroll := SpeechScroll.new()
	scroll._label = label
	var parent := label.get_parent()
	scroll.layout_mode = label.layout_mode
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		scroll.set_anchor(side, label.get_anchor(side))
		scroll.set_offset(side, label.get_offset(side))
	scroll.rotation = label.rotation
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.follow_focus = false
	parent.add_child(scroll)
	parent.move_child(scroll, label.get_index())
	label.reparent(scroll, false)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.position = Vector2.ZERO
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return scroll

func _ready() -> void:
	resized.connect(_fit_label)
	_fit_label()

## A short line still fills the box, so its own vertical alignment holds.
func _fit_label() -> void:
	if _label != null:
		_label.custom_minimum_size = Vector2(0.0, size.y)

func _process(_delta: float) -> void:
	if _label == null or not is_visible_in_tree():
		return
	var ratio := _label.visible_ratio
	if ratio == _last_ratio:
		return
	# A new line starts back at the top.
	if ratio < _last_ratio:
		scroll_vertical = 0
	_last_ratio = ratio
	var overflow := _label.size.y - size.y
	if overflow > 0.0:
		scroll_vertical = int(ceilf(overflow * ratio))
