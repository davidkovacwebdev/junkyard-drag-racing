class_name DragStripBetCard
extends Control
## One rival in the bet field: a driver's placeholder name over a live
## preview of their full car (body, engine and wheels), picked with a click.
## `picked` flags it the same way ScrapButton flags a selected tab — pushed
## in with the yellow sliver — so the chosen car reads as chosen without a
## ring or outline.

signal pressed

const CARD_SIZE := Vector2(140.0, 170.0)

@onready var _car_view: CarView = $CarPreview
@onready var _name_label: Label = $NameLabel

var _board := ScrapBoard.new()
var _picked: bool = false

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	_board.jitter_seed = get_instance_id() % 1000
	_board.tilt_degrees = randf_range(-1.5, 1.5)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(queue_redraw)

func _on_hover() -> void:
	Sfx.play(&"ui_hover", -14.0)
	queue_redraw()

func setup(driver_name: String, car_model: CarModelData) -> void:
	_name_label.text = driver_name
	if car_model != null:
		_car_view.build_from(car_model)

func set_picked(value: bool) -> void:
	_picked = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Sfx.play(&"ui_click", -8.0)
		pressed.emit()

func _draw() -> void:
	_board.body_color = UiPalette.SURFACE_LIGHT if _picked else UiPalette.SURFACE_BASE
	_board.highlight_color = UiPalette.ACCENT_YELLOW if _picked else Color.TRANSPARENT
	_board.draw(self, Rect2(Vector2.ZERO, size), 3.0 if _picked else 0.0)
