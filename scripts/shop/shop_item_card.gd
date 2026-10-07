class_name ShopItemCard
extends Control
## One item in the shop's grid: a cardboard card (like the garage's part
## cards) with the item's icon sat in a dark inset, its name and its price.
## Hovering lightens it and shows the yellow sliver; clicking picks it. One
## the player already owns is faded, says YOURS, and can't be picked.

signal pressed

const CARD_SIZE := Vector2(120.0, 122.0)
## The dark inset the icon sits in, and how big the icon is drawn in it
## (item icons are authored in a roughly 64 px box).
const ICON_GAP := Rect2(14.0, 8.0, 92.0, 52.0)
const ICON_SCALE := 0.72
const OWNED_ALPHA := 0.5
## The card's skirt (ScrapBoard's darker bottom edge): the name and price
## stay on the body above it.
const SKIRT := 7.0
const PRICE_HEIGHT := 18.0

var item: ItemData = null
var owned: bool = false

var _board := ScrapBoard.new()
var _hovering: bool = false
var _icon: Node2D = null
var _name_label: Label
var _price_label: Label

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_board.jitter = 2.0
	_board.nails = false
	_board.skirt_height = SKIRT
	_name_label = _make_label(13, UiPalette.TEXT_BROWN)
	_name_label.position = Vector2(6.0, ICON_GAP.end.y + 1.0)
	_name_label.size = Vector2(CARD_SIZE.x - 12.0, 30.0)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_name_label)
	_price_label = _make_label(16, UiPalette.TEXT_BROWN)
	_price_label.position = Vector2(6.0, CARD_SIZE.y - SKIRT - PRICE_HEIGHT - 5.0)
	_price_label.size = Vector2(CARD_SIZE.x - 12.0, PRICE_HEIGHT)
	add_child(_price_label)
	mouse_entered.connect(_set_hovering.bind(true))
	mouse_exited.connect(_set_hovering.bind(false))
	_refresh()

func setup(new_item: ItemData, is_owned: bool) -> void:
	item = new_item
	owned = is_owned
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	if item == null:
		return
	_name_label.text = item.display_name
	_price_label.text = "YOURS" if owned else "$%d" % item.price
	modulate.a = OWNED_ALPHA if owned else 1.0
	mouse_default_cursor_shape = Control.CURSOR_ARROW if owned else Control.CURSOR_POINTING_HAND
	if _icon != null:
		_icon.queue_free()
		_icon = null
	if item.icon_scene != null:
		_icon = item.icon_scene.instantiate() as Node2D
		_icon.position = ICON_GAP.get_center()
		_icon.scale = Vector2.ONE * ICON_SCALE
		add_child(_icon)
	queue_redraw()

func _set_hovering(value: bool) -> void:
	if value and not owned and not _hovering:
		Sfx.play(&"ui_hover", -14.0)
	_hovering = value and not owned
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if owned:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Sfx.play(&"ui_click", -8.0)
		pressed.emit()

func _draw() -> void:
	var seed := hash(item.id) if item != null else 0
	_board.jitter_seed = seed
	_board.tilt_degrees = float(posmod(seed, 17) - 8) / 10.0
	_board.body_color = UiPalette.CARDBOARD_LIGHT if _hovering else UiPalette.CARDBOARD_BASE
	_board.shade_color = UiPalette.CARDBOARD_SHADE
	_board.skirt_color = UiPalette.CARDBOARD_DARK
	_board.highlight_color = UiPalette.ACCENT_YELLOW if _hovering else Color.TRANSPARENT
	_board.draw(self, Rect2(Vector2.ZERO, size))
	draw_rect(ICON_GAP, UiPalette.SURFACE_DARK)

static func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
