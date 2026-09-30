class_name TrunkSlot
extends Control
## One of the six spaces in the trunk: a cardboard card with a dark inset
## where the item's icon sits (the `ui-style` card). Hovering it lights the
## card a tone and flags it with the yellow sliver; an empty slot stays a
## plain dim card.

signal hovered(slot: TrunkSlot)
signal unhovered(slot: TrunkSlot)

const ICON_SCALE := 0.9
const INSET := 10.0
const SLIVER_HEIGHT := 6.0

var item: ItemData = null:
	set(value):
		item = value
		_rebuild_icon()
		queue_redraw()

var _icon: Node2D = null
var _hover: bool = false
var _board := ScrapBoard.new()

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

func _ready() -> void:
	_board.nails = false
	_board.jitter_seed = get_index() + 211
	_board.tilt_degrees = 1.0 if get_index() % 2 == 0 else -1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		_place_icon()

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

func _place_icon() -> void:
	if _icon == null:
		return
	_icon.position = size * 0.5 - Vector2(0.0, SLIVER_HEIGHT * 0.5)
	var fit := minf(size.x, size.y) / 80.0
	_icon.scale = Vector2.ONE * ICON_SCALE * fit
