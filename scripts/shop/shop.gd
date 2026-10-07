extends Control
## Inside the shop: the shopkeeper behind his counter, the stock on the
## shelves behind him, and the standard CharacterDialog for doing business.
## The bell over the door rings as the player walks in and he greets them
## straight away.
##
## The stock is laid out as a grid of cards (ShopItemCard) under his speech
## board, like the garage's parts: pick one (click it, or its number key) to
## hear his pitch for it, then buy it or look at something else. Leaving
## (the Leave button, or Esc) drops the player back outside the door, like
## every other building.
##
## What's for sale is `stock`, a list of ItemData set in the inspector on
## scenes/shop/shop.tscn; each item's name, price and pitch live on its own
## .tres under res://items.

const WORLD_SCENE := "res://scenes/world/main.tscn"
const SHOPKEEPER := preload("res://characters/shopkeeper.tres")
## Where the shelf row sits and how far apart the goods stand on it, in the
## scene's 1152x648 layout.
const SHELF_Y := 250.0
const SHELF_SPACING := 150.0
const ICON_SCALE := 1.2
const SOLD_ALPHA := 0.3
## The item being looked at stands in the empty bottom-right corner of the
## dialog's speech board (anchored 0.04-0.6 x 0.08-0.44 of the screen).
const PREVIEW_ANCHOR := Vector2(0.6, 0.44)
const PREVIEW_INSET := Vector2(-80.0, -86.0)
const PREVIEW_SCALE := 1.5
## Just above CharacterDialog's own layer, so the preview sits on its board.
const PREVIEW_LAYER := 5
## The shelf keeps a margin either side when the stock grows.
const SHELF_WIDTH_FRACTION := 0.8
const TAG_COLOR := UiPalette.TRIM_OFF_WHITE
## The card grid sits where the dialog's options would, under the speech
## board and left of the shopkeeper (screen fractions), with the Leave
## button under it. It scrolls once the stock outgrows it.
const GRID_RECT := Rect2(0.04, 0.47, 0.57, 0.405)
const GRID_COLUMNS := 5
const GRID_GAP := 8
const LEAVE_POSITION := Vector2(0.04, 0.89)
const LEAVE_SIZE := Vector2(150.0, 46.0)
## The longest an item's `buy_sound` goes off for when it's bought.
const BUY_SOUND_SECONDS := 1.2

@export var shopkeeper_name: String = "Shopkeeper"

@export var stock: Array[ItemData] = []

@export_group("Lines")
@export var greet_line: String = "Welcome, welcome! Everything's for sale. Almost everything works."
@export var browse_line: String = "Anything else catch your eye?"
@export var bought_line: String = "Pleasure doin' business. It's in your trunk."
@export var full_line: String = "Your trunk's full, pal. Make some room first."
@export var broke_line: String = "Come back when you got the cash, pal."
@export var owned_line: String = "You already got one of those."

var _leaving: bool = false
var _shelf_icons: Dictionary = {}  # item id -> Node2D
var _shelf_tags: Dictionary = {}  # item id -> Label
## The card grid is up (not an item's pitch).
var _browsing: bool = false
var _preview_layer: CanvasLayer
var _preview: Node2D = null
var _grid_root: Control
var _grid: GridContainer
var _cards: Array[ShopItemCard] = []

@onready var _dialog: CharacterDialog = $Dialog
@onready var _goods: Control = $Content/Goods

func _ready() -> void:
	_stock_shelves()
	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = PREVIEW_LAYER
	add_child(_preview_layer)
	_build_grid()
	_dialog.closed.connect(_leave)
	Sfx.play(&"shop_bell", -6.0, 0.02)
	_greet.call_deferred()

func _greet() -> void:
	_dialog.open(shopkeeper_name, SHOPKEEPER)
	_dialog.say(PlayerProfile.fill(SHOPKEEPER.idle_line(greet_line)))
	_show_stock(true)

## The goods stand in a row on the shelf, each with its price chalked under
## it. Sold-out ones stay on the shelf, faded, so the shelf doesn't reshuffle.
func _stock_shelves() -> void:
	var spacing := SHELF_SPACING
	if stock.size() > 1:
		spacing = minf(SHELF_SPACING, size.x * SHELF_WIDTH_FRACTION / (stock.size() - 1))
	var first_x := size.x * 0.5 - spacing * (stock.size() - 1) * 0.5
	for i in stock.size():
		var item := stock[i]
		if item == null or item.icon_scene == null:
			continue
		var icon := item.icon_scene.instantiate() as Node2D
		icon.position = Vector2(first_x + i * spacing, SHELF_Y - 40.0)
		icon.scale = Vector2.ONE * ICON_SCALE
		_goods.add_child(icon)
		_shelf_icons[item.id] = icon
		var tag := Label.new()
		tag.text = "$%d" % item.price
		tag.add_theme_font_size_override("font_size", 20)
		tag.add_theme_color_override("font_color", TAG_COLOR)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.position = Vector2(first_x + i * spacing - 50.0, SHELF_Y + 16.0)
		tag.size = Vector2(100.0, 26.0)
		_goods.add_child(tag)
		_shelf_tags[item.id] = tag
	_refresh_shelves()

func _refresh_shelves() -> void:
	for id in _shelf_icons:
		(_shelf_icons[id] as Node2D).modulate.a = SOLD_ALPHA if Inventory.has_item(id) else 1.0

func _for_sale() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for item in stock:
		if item != null:
			items.append(item)
	return items

## The grid of cards and the Leave button under it, on the preview's layer
## so they sit on top of the dialog. Hidden while an item's being pitched.
func _build_grid() -> void:
	_grid_root = Control.new()
	_grid_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_root.visible = false
	_preview_layer.add_child(_grid_root)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = GRID_RECT.position.x
	scroll.anchor_top = GRID_RECT.position.y
	scroll.anchor_right = GRID_RECT.end.x
	scroll.anchor_bottom = GRID_RECT.end.y
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	scroll.add_child(_grid)
	for item in _for_sale():
		var card := ShopItemCard.new()
		card.setup(item, false)
		card.pressed.connect(_on_item_picked.bind(item))
		_grid.add_child(card)
		_cards.append(card)
	var leave := ScrapButton.new()
	leave.text = "Leave"
	leave.font_size = 20
	leave.tilt_degrees = -1.0
	leave.jitter_seed = 77
	leave.anchor_left = LEAVE_POSITION.x
	leave.anchor_top = LEAVE_POSITION.y
	leave.anchor_right = LEAVE_POSITION.x
	leave.anchor_bottom = LEAVE_POSITION.y
	leave.offset_right = LEAVE_SIZE.x
	leave.offset_bottom = LEAVE_SIZE.y
	leave.pressed.connect(_dialog.close)
	_grid_root.add_child(leave)

## Browsing: the dialog's own options give way to the card grid.
func _show_stock(_animate: bool = false) -> void:
	_browsing = true
	_show_preview(null)
	_dialog.set_options([], false)
	for card in _cards:
		card.setup(card.item, Inventory.has_item(card.item.id))
	_grid_root.visible = true
	_show_wallet()
	_refresh_shelves()

## The Leave button and Esc both close the dialog; the grid goes the moment
## it starts closing, not after it has slid away.
func _process(_delta: float) -> void:
	if _grid_root.visible and not _dialog.is_open():
		_grid_root.visible = false

## Number keys pick the card with that number while the grid is up.
func _input(event: InputEvent) -> void:
	if not _browsing or not _dialog.is_open() or not event is InputEventKey \
			or not event.pressed or event.echo:
		return
	var index: int = event.keycode - KEY_1
	if index < 0 or index >= mini(_cards.size(), 9):
		return
	get_viewport().set_input_as_handled()
	var card := _cards[index]
	if not card.owned:
		Sfx.play(&"ui_click", -8.0)
		_on_item_picked(card.item)

func _on_item_picked(item: ItemData) -> void:
	_browsing = false
	_grid_root.visible = false
	_refresh_shelves()
	_dialog.say(item.description)
	_show_preview(item)
	_dialog.set_options([
		CharacterDialog.Option.new("Buy it ($%d)" % item.price, _on_buy_pressed.bind(item)),
		CharacterDialog.Option.new("Something else", _on_browse_pressed),
	], true)
	_show_wallet()

func _on_buy_pressed(item: ItemData) -> void:
	if Inventory.has_item(item.id):
		_dialog.say(owned_line)
	elif Inventory.is_trunk_full():
		Sfx.play(&"denied", -6.0, 0.0)
		_dialog.say(full_line)
	elif Inventory.buy_item(item):
		Sfx.play(&"cash_register", -4.0, 0.0)
		if not item.buy_sound.is_empty():
			_play_buy_sound(item.buy_sound, item.buy_sound_volume_db)
		_dialog.say(bought_line)
		_refresh_shelves()
	else:
		Sfx.play(&"denied", -6.0, 0.0)
		_dialog.say(broke_line)
	_show_stock(true)

## A taste of what was just bought, cut off after `BUY_SOUND_SECONDS` (a
## loop like the Super Horn would otherwise blare on forever).
func _play_buy_sound(sound_name: StringName, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = Sfx.stream(sound_name)
	player.bus = SoundLibrary.bus_for(sound_name)
	player.volume_db = volume_db
	add_child(player)
	player.play()
	get_tree().create_timer(BUY_SOUND_SECONDS).timeout.connect(player.queue_free)

func _on_browse_pressed() -> void:
	_dialog.say(browse_line)
	_show_stock(true)

## Puts `item`'s icon on the speech board, popped in; null clears it.
func _show_preview(item: ItemData) -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
	if item == null or item.icon_scene == null:
		return
	_preview = item.icon_scene.instantiate() as Node2D
	var screen := get_viewport_rect().size
	_preview.position = screen * PREVIEW_ANCHOR + PREVIEW_INSET
	_preview_layer.add_child(_preview)
	_preview.scale = Vector2.ONE * PREVIEW_SCALE * 0.6
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_preview, "scale", Vector2.ONE * PREVIEW_SCALE, 0.3)

func _show_wallet() -> void:
	_dialog.set_note("You have $%d" % Inventory.money)

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_show_preview(null)
	_grid_root.visible = false
	SaveSystem.save_game()
	SceneLoader.change_scene(WORLD_SCENE)
