class_name SortButton
extends ScrapButton
## "Sort: Speed" - each press moves to the next PartSort key.

signal sort_changed(key: PartSort.Key)

var key: PartSort.Key = PartSort.Key.NAME

func _ready() -> void:
	super()
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_next_key)
	_show_key()

func _next_key() -> void:
	key = ((key + 1) % PartSort.Key.size()) as PartSort.Key
	_show_key()
	sort_changed.emit(key)

func _show_key() -> void:
	text = "Sort: %s" % PartSort.LABELS[key]
