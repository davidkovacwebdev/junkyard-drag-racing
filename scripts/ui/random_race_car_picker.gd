class_name RandomRaceCarPicker
extends Control
## The random race popup's "Pick a Car" window: one tier's rival pool (the
## roster cars its headliner is drawn from, best first) down the left, and the
## highlighted car's preview, stat bars and parts on the right. "Drive It"
## hands the car back to RandomRacePopup, which puts it in the first lane.

signal car_picked(spec: Dictionary)

const TIERS := [1, 2, 3, 4]
const COURSE_SCORE_LABELS := {
	RaceProgression.Course.DRAG: "Drag strip time: %.2f s",
	RaceProgression.Course.HILL: "Hill climb time: %.2f s",
	RaceProgression.Course.DERBY: "Derby weakness: %.2f",
}
const COURSE_ROW_SCORES := {
	RaceProgression.Course.DRAG: "%.1fs",
	RaceProgression.Course.HILL: "%.1fs",
	RaceProgression.Course.DERBY: "%.2f",
}
## Longer names are cut short in the list; the details card shows them whole.
const ROW_NAME_MAX_CHARS := 36
const _CAR_STATS_CARD_SCENE := preload("res://scenes/garage/car_stats_card.tscn")
const _CAR_VIEW_SCENE := preload("res://scenes/world/car_view.tscn")

var tier: int = 1
var _course := RaceProgression.Course.DRAG
var _pool: Array[Dictionary] = []
var _highlighted_index := -1
## Highlighted again whenever its pool is shown, so reopening lands on it.
var _remembered_spec: Dictionary = {}
## Scene path -> PartData, so a pool of a few hundred cars only instances each
## part scene once. Display only: the car that races is built fresh.
var _part_cache := {}

var _tier_buttons: Array[ScrapButton] = []
var _scroll: ScrollContainer
var _car_list: VBoxContainer
var _car_buttons: Array[ScrapButton] = []
var _course_label: Label
var _car_view: CarView
var _car_name_label: Label
var _score_label: Label
var _parts_label: Label
var _stats_card: CarStatsCard
var _drive_button: ScrapButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()

## Shows `pool_tier`'s pool rated on `course`, with `picked_spec` highlighted
## when it's in there; a tier outside 1-4 keeps the last tier shown.
func open(pool_tier: int, course: RaceProgression.Course, picked_spec: Dictionary = {}) -> void:
	if pool_tier in TIERS:
		tier = pool_tier
	_course = course
	_remembered_spec = picked_spec
	visible = true
	Sfx.play(&"trunk_open", -8.0)
	_show_pool()

func close() -> void:
	if visible:
		visible = false
		Sfx.play(&"trunk_close", -10.0)

## A short name for a roster car: its body and engine.
func car_label(spec: Dictionary) -> String:
	return "%s + %s" % [_part(spec["body"]).display_name, _part(spec["engine"]).display_name]

# --- Building ------------------------------------------------------------------

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.4)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	var panel := ScrapPanel.new()
	panel.body_color = UiPalette.STEEL_DARK
	panel.shade_color = Color(0.33, 0.36, 0.41)
	panel.skirt_color = UiPalette.METAL_GREY
	panel.tilt_degrees = -0.5
	panel.jitter_seed = 83
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -500.0
	panel.offset_right = 500.0
	panel.offset_top = -290.0
	panel.offset_bottom = 290.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.add_child(panel)

	var title_plate := ScrapPanel.new()
	title_plate.body_color = UiPalette.ACCENT_YELLOW
	title_plate.shade_color = Color(0.85, 0.66, 0.08)
	title_plate.skirt_color = Color(0.76, 0.58, 0.07)
	title_plate.nails = false
	title_plate.tilt_degrees = 2.5
	title_plate.jitter_seed = 84
	title_plate.position = Vector2(22.0, -14.0)
	title_plate.size = Vector2(220.0, 58.0)
	title_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_plate)
	var title := _make_label("PICK A CAR", 26, UiPalette.INK)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.offset_bottom = -6.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_plate.add_child(title)

	_course_label = _make_label("", 15, UiPalette.STEEL_LIGHT)
	_course_label.position = Vector2(300.0, 20.0)
	_course_label.size = Vector2(676.0, 24.0)
	_course_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_course_label)

	var tier_row := HBoxContainer.new()
	tier_row.position = Vector2(30.0, 62.0)
	tier_row.add_theme_constant_override("separation", 12)
	panel.add_child(tier_row)
	for i in TIERS.size():
		var button := _make_button("Tier %d" % TIERS[i], 18, 1.5 if i % 2 == 0 else -1.5, 200 + i)
		button.custom_minimum_size = Vector2(110.0, 44.0)
		button.pressed.connect(_on_tier_pressed.bind(TIERS[i]))
		tier_row.add_child(button)
		_tier_buttons.append(button)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(30.0, 126.0)
	_scroll.size = Vector2(450.0, 410.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_car_list = VBoxContainer.new()
	_car_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_car_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_car_list)

	var details := ScrapPanel.new()
	details.body_color = UiPalette.CARDBOARD_BASE
	details.shade_color = UiPalette.CARDBOARD_SHADE
	details.skirt_color = UiPalette.CARDBOARD_DARK
	details.nails = false
	details.tilt_degrees = 0.8
	details.jitter_seed = 85
	details.position = Vector2(504.0, 126.0)
	details.size = Vector2(466.0, 352.0)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(details)

	_car_view = _CAR_VIEW_SCENE.instantiate()
	_car_view.auto_fit_width = 200.0
	_car_view.max_height = 110.0
	_car_view.position = Vector2(233.0, 80.0)
	details.add_child(_car_view)

	_car_name_label = _make_label("", 18, UiPalette.TEXT_BROWN)
	_car_name_label.position = Vector2(16.0, 148.0)
	_car_name_label.size = Vector2(434.0, 44.0)
	_car_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_car_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_car_name_label)

	_stats_card = _CAR_STATS_CARD_SCENE.instantiate()
	_stats_card.position = Vector2(43.0, 196.0)
	details.add_child(_stats_card)

	_score_label = _make_label("", 16, UiPalette.TEXT_BROWN)
	_score_label.position = Vector2(20.0, 262.0)
	_score_label.size = Vector2(426.0, 22.0)
	details.add_child(_score_label)

	_parts_label = _make_label("", 15, UiPalette.TEXT_BROWN)
	_parts_label.position = Vector2(20.0, 286.0)
	_parts_label.size = Vector2(426.0, 60.0)
	_parts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_parts_label)

	var back_button := _make_button("Back", 22, 1.5, 210)
	back_button.position = Vector2(504.0, 494.0)
	back_button.size = Vector2(150.0, 52.0)
	back_button.pressed.connect(close)
	panel.add_child(back_button)

	_drive_button = _make_button("Drive It", 24, -1.5, 211)
	_drive_button.position = Vector2(770.0, 494.0)
	_drive_button.size = Vector2(200.0, 52.0)
	_drive_button.pressed.connect(_on_drive_pressed)
	panel.add_child(_drive_button)

func _make_button(text: String, font_size: int, tilt: float, jitter_seed: int) -> ScrapButton:
	var button := ScrapButton.new()
	button.text = text
	button.font_size = font_size
	button.tilt_degrees = tilt
	button.jitter_seed = jitter_seed
	button.focus_mode = Control.FOCUS_NONE
	return button

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# --- Pool ----------------------------------------------------------------------

func _show_pool() -> void:
	for i in _tier_buttons.size():
		_tier_buttons[i].selected = TIERS[i] == tier
	_pool = RaceProgression.tier_pool(tier, _course)
	_course_label.text = "%d cars, rated on the %s roster" % [_pool.size(), _course_name()]
	for button in _car_buttons:
		button.queue_free()
	_car_buttons.clear()
	var row_score: String = COURSE_ROW_SCORES[_course]
	var key := RaceProgression.score_key(_course)
	for i in _pool.size():
		var spec := _pool[i]
		var extras := Array(spec.get("accessories", [])).size()
		var row_name := car_label(spec)
		if row_name.length() > ROW_NAME_MAX_CHARS:
			row_name = row_name.left(ROW_NAME_MAX_CHARS - 3).strip_edges() + "..."
		var text := "%s   %s" % [row_score % float(spec[key]), row_name]
		if extras > 0:
			text += "  +%d" % extras
		var button := _make_button(text, 16, 0.6 if i % 2 == 0 else -0.6, 300 + i)
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_highlight.bind(i))
		_car_list.add_child(button)
		_car_buttons.append(button)
	var remembered_index := _pool.find(_remembered_spec)
	_highlight(remembered_index if remembered_index >= 0 else (0 if not _pool.is_empty() else -1))
	_scroll.scroll_vertical = 0
	if remembered_index >= 0:
		var remembered_button := _car_buttons[remembered_index]
		# The list only has its size after the next layout pass.
		await get_tree().process_frame
		if is_instance_valid(remembered_button) and not remembered_button.is_queued_for_deletion():
			_scroll.ensure_control_visible(remembered_button)

func _highlight(index: int) -> void:
	_highlighted_index = index
	for i in _car_buttons.size():
		_car_buttons[i].selected = i == index
	_drive_button.disabled = index < 0
	if index < 0:
		_car_view.build_from(null)
		_stats_card.show_car(null)
		_car_name_label.text = "No cars in this pool"
		_score_label.text = ""
		_parts_label.text = ""
		return
	var spec := _pool[index]
	var car := _display_car(spec)
	_car_view.build_from(car)
	_stats_card.show_car(car)
	_car_name_label.text = car_label(spec)
	_score_label.text = COURSE_SCORE_LABELS[_course] % float(spec[RaceProgression.score_key(_course)])
	var wheel_names: Array = Array(spec["wheels"]).map(func(path: String) -> String: return _part(path).display_name)
	var extra_names: Array = Array(spec.get("accessories", [])).map(func(path: String) -> String: return _part(path).display_name)
	_parts_label.text = "Wheels: %s\nExtras: %s" % [
		", ".join(wheel_names), ", ".join(extra_names) if not extra_names.is_empty() else "none",
	]

func _display_car(spec: Dictionary) -> CarModelData:
	var car := CarModelData.new()
	car.body = _part(spec["body"]) as BodyPartData
	car.engine = _part(spec["engine"]) as EnginePartData
	var wheels: Array[WheelPartData] = []
	for path in spec["wheels"]:
		wheels.append(_part(path) as WheelPartData)
	car.wheels = wheels
	var accessories: Array[AccessoryPartData] = []
	for path in spec.get("accessories", []):
		accessories.append(_part(path) as AccessoryPartData)
	car.accessories = accessories
	return car

func _part(scene_path: String) -> PartData:
	if not _part_cache.has(scene_path):
		_part_cache[scene_path] = PartDatabase.load_part_data(scene_path)
	return _part_cache[scene_path]

func _course_name() -> String:
	match _course:
		RaceProgression.Course.HILL:
			return "hill climb"
		RaceProgression.Course.DERBY:
			return "derby"
	return "drag strip"

func _on_tier_pressed(pool_tier: int) -> void:
	tier = pool_tier
	_show_pool()

func _on_drive_pressed() -> void:
	if _highlighted_index < 0:
		return
	Sfx.play(&"ignition_click", -4.0)
	car_picked.emit(_pool[_highlighted_index])
	visible = false

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		close()
