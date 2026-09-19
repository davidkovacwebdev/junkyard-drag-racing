class_name Garage
extends Control
## Placeholder garage screen: browse the player's owned cars with the
## prev/next arrows. Fixed pixel layout for now, not responsive — fine
## for a single early-game screen.

@onready var _car_visual: CarVisual = $CarPreview
@onready var _name_label: Label = $NameLabel

var _index: int = 0
var _escape_pressed_last: bool = false

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	var escape_pressed := Input.is_physical_key_pressed(KEY_ESCAPE)
	if escape_pressed and not _escape_pressed_last:
		get_tree().change_scene_to_file("res://scenes/world/main.tscn")
	_escape_pressed_last = escape_pressed

func _on_prev_pressed() -> void:
	_cycle(-1)

func _on_next_pressed() -> void:
	_cycle(1)

func _cycle(step: int) -> void:
	var count := Inventory.owned_cars.size()
	if count == 0:
		return
	_index = (_index + step + count) % count
	_refresh()

func _refresh() -> void:
	var cars := Inventory.owned_cars
	if cars.is_empty():
		_name_label.text = "No cars in the garage yet"
		_car_visual.visible = false
		return
	_car_visual.visible = true
	var car: CarModelData = cars[_index]
	_car_visual.set_body_color(car.body_color)
	_name_label.text = "%s  (%d/%d)" % [car.display_name, _index + 1, cars.size()]
