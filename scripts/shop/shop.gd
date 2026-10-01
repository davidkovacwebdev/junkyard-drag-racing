extends Control
## Inside the shop: the shopkeeper behind his counter, the stock on the
## shelves behind him, and the standard CharacterDialog for doing business.
## The bell over the door rings as the player walks in and he greets them
## straight away.
##
## Pick an item to hear his pitch for it, then buy it or look at something
## else. Leaving (the Leave option, or Esc) drops the player back outside
## the door, like every other building.
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
var _preview_layer: CanvasLayer
var _preview: Node2D = null

@onready var _dialog: CharacterDialog = $Dialog
@onready var _goods: Control = $Content/Goods

func _ready() -> void:
	_stock_shelves()
	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = PREVIEW_LAYER
	add_child(_preview_layer)
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
	var first_x := size.x * 0.5 - SHELF_SPACING * (stock.size() - 1) * 0.5
	for i in stock.size():
		var item := stock[i]
		if item == null or item.icon_scene == null:
			continue
		var icon := item.icon_scene.instantiate() as Node2D
		icon.position = Vector2(first_x + i * SHELF_SPACING, SHELF_Y - 40.0)
		icon.scale = Vector2.ONE * ICON_SCALE
		_goods.add_child(icon)
		_shelf_icons[item.id] = icon
		var tag := Label.new()
		tag.text = "$%d" % item.price
		tag.add_theme_font_size_override("font_size", 20)
		tag.add_theme_color_override("font_color", UiPalette.TRIM_OFF_WHITE)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.position = Vector2(first_x + i * SHELF_SPACING - 50.0, SHELF_Y + 16.0)
		tag.size = Vector2(100.0, 26.0)
		_goods.add_child(tag)
	_refresh_shelves()

func _refresh_shelves() -> void:
	for id in _shelf_icons:
		(_shelf_icons[id] as Node2D).modulate.a = SOLD_ALPHA if Inventory.has_item(id) else 1.0

## The main menu of the dialog: one option per item, plus Leave.
func _show_stock(animate: bool = false) -> void:
	_show_preview(null)
	var options: Array = []
	for item in stock:
		if item == null:
			continue
		var owned := Inventory.has_item(item.id)
		var label := "%s  -  $%d" % [item.display_name, item.price]
		if owned:
			label = "%s  (yours)" % item.display_name
		options.append(CharacterDialog.Option.new(label, _on_item_picked.bind(item), owned))
	options.append(CharacterDialog.Option.new("Leave", _dialog.close))
	_dialog.set_options(options, animate)
	_show_wallet()

func _on_item_picked(item: ItemData) -> void:
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
		_dialog.say(bought_line)
		_refresh_shelves()
	else:
		Sfx.play(&"denied", -6.0, 0.0)
		_dialog.say(broke_line)
	_show_stock(true)

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
	SaveSystem.save_game()
	get_tree().change_scene_to_file(WORLD_SCENE)
