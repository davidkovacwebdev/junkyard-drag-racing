class_name TrunkSlot
extends Control
## One of the six spaces in the trunk: a cardboard card with a dark inset
## where the item's icon sits (the `ui-style` card). Hovering it lights the
## card a tone and flags it with the yellow sliver; an empty slot stays a
## plain dim card.
##
## Its number key sits in the top-left corner, and a usable item's uses left
## ("x6") in the bottom-right. Double-clicking it asks to use the item.

signal hovered(slot: TrunkSlot)
signal unhovered(slot: TrunkSlot)
signal activated(slot: TrunkSlot)

const ICON_SCALE := 0.9
const INSET := 10.0
const SLIVER_HEIGHT := 6.0

var item: ItemData = null:
	set(value):
		item = value
		_rebuild_icon()
		refresh_count()
		queue_redraw()

var _icon: Node2D = null
var _hover: bool = false
var _board := ScrapBoard.new()
var _key_label: Label
var _count_label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw()
		hovered.emit(self))
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw()
		unhovered.emit(self))
	_key_label = _make_label(16, UiPalette.TEXT_BROWN, HORIZONTAL_ALIGNMENT_LEFT)
	_count_label = _make_label(20, UiPalette.TEXT_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)

func _ready() -> void:
	_board.nails = false
	_board.jitter_seed = get_index() + 211
	_board.tilt_degrees = 1.0 if get_index() % 2 == 0 else -1.0
	_key_label.text = str(get_index() + 1)
	_place_labels()

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed \
			and click.double_click and item != null:
		activated.emit(self)
		accept_event()

## Shows how many uses the item has left; nothing for items that can't be used.
func refresh_count() -> void:
	var left := Inventory.uses_left(item)
	_count_label.text = "x%d" % left if left > 0 else ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		_place_icon()
		_place_labels()

func _draw() -> void:
	var lit := _hover and item != null
	_board.body_color = UiPalette.CARDBOARD_LIGHT if lit else UiPalette.CARDBOARD_BASE
	_board.shade_color = UiPalette.CARDBOARD_SHADE
	_board.skirt_color = UiPalette.CARDBOARD_DARK
	_board.highlight_color = UiPalette.ACCENT_YELLOW if lit else Color.TRANSPARENT
	_board.draw(self, Rect2(Vector2.ZERO, size))
	var gap := Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET + SLIVER_HEIGHT) * 2.0)
	draw_rect(gap, UiPalette.CARDBOARD_DARK if item != null else UiPalette.STAT_EMPTY)

func _rebuild_icon() -> void:
	if _icon != null:
		_icon.queue_free()
		_icon = null
	if item == null or item.icon_scene == null:
		return
	_icon = item.icon_scene.instantiate() as Node2D
	add_child(_icon)
	_place_icon()

func _make_label(font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 1
	add_child(label)
	return label

## The key number tucked in the top-left corner of the inset, the count in
## the bottom-right.
func _place_labels() -> void:
	if _key_label == null:
		return
	_key_label.position = Vector2(INSET + 4.0, INSET)
	_key_label.size = Vector2(30.0, 20.0)
	_count_label.position = Vector2(size.x - INSET - 64.0, size.y - INSET - SLIVER_HEIGHT * 2.0 - 24.0)
	_count_label.size = Vector2(60.0, 24.0)

func _place_icon() -> void:
	if _icon == null:
		return
	_icon.position = size * 0.5 - Vector2(0.0, SLIVER_HEIGHT * 0.5)
	var fit := minf(size.x, size.y) / 80.0
	_icon.scale = Vector2.ONE * ICON_SCALE * fit
