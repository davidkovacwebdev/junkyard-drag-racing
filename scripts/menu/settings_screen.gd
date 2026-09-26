extends Control
## Settings screen: one row per audio bus with a volume bar and a mute toggle,
## all backed by AudioSettings. Changing a volume plays a sample through that
## bus so you hear the new level (Music just plays on).

const ROWS := [
	[AudioSettings.MASTER, "Master"],
	[AudioSettings.MUSIC, "Music"],
	[AudioSettings.SFX, "Sound Effects"],
	[AudioSettings.CARS, "Cars"],
	[AudioSettings.AMBIENCE, "Ambience"],
	[AudioSettings.UI, "Interface"],
]
const PREVIEW_SOUNDS := {
	AudioSettings.MASTER: &"ui_click",
	AudioSettings.SFX: &"scrap_pickup",
	AudioSettings.CARS: &"backfire",
	AudioSettings.AMBIENCE: &"ui_click",
	AudioSettings.UI: &"ui_click",
}

@onready var _rows: VBoxContainer = $Board/Rows

func _ready() -> void:
	for i in ROWS.size():
		_add_row(ROWS[i][0], ROWS[i][1], i)

func _add_row(bus_name: StringName, label_text: String, index: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_rows.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiPalette.TEXT_BROWN)
	label.add_theme_font_size_override("font_size", 24)
	row.add_child(label)

	var volume_bar := VolumeBar.new()
	volume_bar.custom_minimum_size = Vector2(240, 30)
	volume_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_bar.value = AudioSettings.get_volume(bus_name)
	volume_bar.muted = AudioSettings.is_muted(bus_name)
	volume_bar.value_changed.connect(_on_volume_changed.bind(bus_name))
	row.add_child(volume_bar)

	var mute_button := ScrapButton.new()
	mute_button.custom_minimum_size = Vector2(110, 40)
	mute_button.toggle_mode = true
	mute_button.font_size = 20
	mute_button.tilt_degrees = 1.5 if index % 2 == 0 else -1.5
	mute_button.jitter_seed = 40 + index
	mute_button.set_pressed_no_signal(AudioSettings.is_muted(bus_name))
	_show_mute_state(mute_button, mute_button.button_pressed)
	mute_button.toggled.connect(_on_mute_toggled.bind(bus_name, mute_button, volume_bar))
	row.add_child(mute_button)

func _on_volume_changed(volume: float, bus_name: StringName) -> void:
	AudioSettings.set_volume(bus_name, volume)
	if PREVIEW_SOUNDS.has(bus_name):
		Sfx.play(PREVIEW_SOUNDS[bus_name], -6.0, 0.0, bus_name)

func _on_mute_toggled(muted: bool, bus_name: StringName, mute_button: ScrapButton, volume_bar: VolumeBar) -> void:
	AudioSettings.set_muted(bus_name, muted)
	volume_bar.muted = muted
	_show_mute_state(mute_button, muted)

func _show_mute_state(mute_button: ScrapButton, muted: bool) -> void:
	mute_button.selected = muted
	mute_button.text = "Muted" if muted else "Mute"
