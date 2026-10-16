class_name PartFoundCard
extends CanvasLayer
## The cardboard board that slides in top-left when the car drives through a
## part orb. The part flies from the orb into a disc in its category colour,
## then its Durability and Speed click in block by block, each with how it
## compares to the part fitted on the car now. Grabs in quick succession stack
## downwards instead of covering each other.

const PART_ICON_SCENE := preload("res://scenes/garage/part_icon.tscn")

const LAYER := 38
const BOARD_SIZE := Vector2(330.0, 108.0)
const SCREEN_MARGIN := Vector2(18.0, 18.0)
const STACK_GAP := 12.0
## Room under the quest tracker, clear of its skirt and shadow.
const TRACKER_GAP := 20.0
const DISC_CENTER := Vector2(52.0, 50.0)
const DISC_RADIUS := 36.0
const ICON_SIZE := 64.0
const TEXT_LEFT := 102.0

const SLIDE_IN := 0.4
const HOLD := 2.6
const SLIDE_OUT := 0.35
const FLY_TIME := 0.5
const FLY_ARC := 70.0
const STATS_START := 0.5
const BLOCK_INTERVAL := 0.11
## How long the card stays up after the last block clicks in, when that runs
## past HOLD.
const READ_TIME_AFTER_STATS := 1.4

const STAT_NAMES := ["DURABILITY", "SPEED"]
const STAT_ROW_CENTERS := [68.0, 88.0]
const STAT_BLOCKS_LEFT := 200.0

## Stack positions in use, so a second card goes under the first.
static var _taken_slots: Array[int] = []

var _part: PartData
var _from_screen: Vector2
var _slot := 0
var _age := 0.0
var _ratings: Array[int] = []
## Rating minus the fitted part's, per stat; empty when nothing is fitted.
var _deltas: Array[int] = []
var _blocks_shown := 0
var _board: ScrapPanel
var _details: Control
var _icon: PartIcon
var _plate_label: Label
var _delta_labels: Array[Label] = []

static func spawn(context: Node, part: PartData, from_screen: Vector2) -> void:
	var scene := context.get_tree().current_scene
	if scene == null:
		return
	var card := PartFoundCard.new()
	card._part = part
	card._from_screen = from_screen
	scene.add_child(card)

func _ready() -> void:
	layer = LAYER
	_slot = _claim_slot()
	_read_stats()
	_build_board()
	_build_icon()
	_place(0.0)
	Sfx.play(&"part_card_slide", -8.0)

func _exit_tree() -> void:
	_taken_slots.erase(_slot)

static func _claim_slot() -> int:
	var slot := 0
	while _taken_slots.has(slot):
		slot += 1
	_taken_slots.append(slot)
	return slot

func _read_stats() -> void:
	_ratings = [
		StatBar.rating_for(_part.durability_rating_fraction()),
		StatBar.rating_for(_part.speed_rating_fraction()),
	]
	var fitted := _fitted_counterpart()
	if fitted != null:
		_deltas = [
			_ratings[0] - StatBar.rating_for(fitted.durability_rating_fraction()),
			_ratings[1] - StatBar.rating_for(fitted.speed_rating_fraction()),
		]

## The part this one would replace on the selected car, or null.
func _fitted_counterpart() -> PartData:
	var car := Inventory.get_selected_car()
	if car == null:
		return null
	match _part.category:
		PartData.Category.BODY:
			return car.body
		PartData.Category.ENGINE:
			return car.engine
		PartData.Category.WHEEL:
			return car.wheels[0] if not car.wheels.is_empty() else null
		PartData.Category.ACCESSORY:
			if _part is AccessoryPartData:
				return car.accessory_in((_part as AccessoryPartData).spot)
	return null

func _build_board() -> void:
	_board = ScrapPanel.new()
	_board.body_color = UiPalette.CARDBOARD_BASE
	_board.shade_color = UiPalette.CARDBOARD_SHADE
	_board.skirt_color = UiPalette.CARDBOARD_DARK
	_board.tilt_degrees = -1.4
	_board.jitter_seed = 517 + _slot
	_board.nails = false
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.size = BOARD_SIZE
	add_child(_board)
	_details = Control.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.size = BOARD_SIZE
	_details.draw.connect(_draw_details)
	_board.add_child(_details)

	_plate_label = _label("NEW " + PartData.Category.keys()[_part.category], 13, UiPalette.INK,
			Vector2(TEXT_LEFT + 6.0, 11.0))
	var name_label := _label(_part.display_name, 22, UiPalette.TEXT_BROWN, Vector2(TEXT_LEFT, 32.0))
	name_label.size.x = BOARD_SIZE.x - TEXT_LEFT - 14.0
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for row in STAT_NAMES.size():
		_label(STAT_NAMES[row], 13, UiPalette.SURFACE_DARK, Vector2(TEXT_LEFT, STAT_ROW_CENTERS[row] - 9.0))
		var delta_label := _label("", 18, UiPalette.TEXT_BROWN,
				Vector2(STAT_BLOCKS_LEFT + StatBar.BLOCK_COUNT * (StatBar.BLOCK_WIDTH + StatBar.BLOCK_GAP) + 4.0,
				STAT_ROW_CENTERS[row] - 12.0))
		delta_label.visible = false
		if not _deltas.is_empty() and _deltas[row] != 0:
			delta_label.text = "%+d" % _deltas[row]
			if _deltas[row] < 0:
				delta_label.add_theme_color_override("font_color", UiPalette.DANGER_RED)
		_delta_labels.append(delta_label)

func _label(text: String, font_size: int, color: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(label)
	return label

func _build_icon() -> void:
	_icon = PART_ICON_SCENE.instantiate()
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.pivot_offset = Vector2(ICON_SIZE, ICON_SIZE) * 0.5
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_icon.show_part(_part)

func _process(delta: float) -> void:
	visible = Journal.hud_allowed()
	_age += delta
	if _age >= _lifetime():
		queue_free()
		return
	_place(_age)
	_reveal_stats()

func _lifetime() -> float:
	var stats_done := STATS_START + _total_blocks() * BLOCK_INTERVAL + READ_TIME_AFTER_STATS
	return SLIDE_IN + maxf(HOLD, stats_done - SLIDE_IN) + SLIDE_OUT

func _total_blocks() -> int:
	return _ratings[0] + _ratings[1]

func _place(age: float) -> void:
	var slide := _ease_out_back(clampf(age / SLIDE_IN, 0.0, 1.0))
	var out_start := _lifetime() - SLIDE_OUT
	if age > out_start:
		slide = 1.0 - _ease_in_back(clampf((age - out_start) / SLIDE_OUT, 0.0, 1.0))
	var hidden_x := -BOARD_SIZE.x - 40.0
	_board.position = Vector2(lerpf(hidden_x, SCREEN_MARGIN.x, slide),
			_stack_top() + _slot * (BOARD_SIZE.y + STACK_GAP))

	var disc := _board.position + DISC_CENTER
	var fly := clampf(age / FLY_TIME, 0.0, 1.0)
	if fly < 1.0:
		var eased := smoothstep(0.0, 1.0, fly)
		var center := _from_screen.lerp(disc, eased) + Vector2(0.0, -sin(eased * PI) * FLY_ARC)
		_icon.position = center - _icon.size * 0.5
		_icon.rotation = eased * TAU
		_icon.scale = Vector2.ONE * lerpf(0.8, 1.0, eased)
	else:
		_icon.position = disc - _icon.size * 0.5
		_icon.rotation = sin(age * 2.0) * 0.08
		_icon.scale = Vector2.ONE

## Under the quest tracker when one is pinned, else the screen's top margin.
func _stack_top() -> float:
	var tracker_bottom := Journal.tracker_bottom()
	if tracker_bottom <= 0.0:
		return SCREEN_MARGIN.y
	return tracker_bottom + TRACKER_GAP

func _reveal_stats() -> void:
	var due := clampi(floori((_age - STATS_START) / BLOCK_INTERVAL) + 1, 0, _total_blocks())
	while _blocks_shown < due:
		var tick := Sfx.play(&"stat_tick", -12.0, 0.0)
		tick.pitch_scale = 1.0 + 0.07 * _blocks_shown
		_blocks_shown += 1
		_details.queue_redraw()
	for row in _delta_labels.size():
		var row_end := _ratings[0] if row == 0 else _total_blocks()
		_delta_labels[row].visible = _blocks_shown >= row_end and not _delta_labels[row].text.is_empty()

func _draw_details() -> void:
	var disc := PackedVector2Array()
	for i in 14:
		var angle := TAU * i / 14.0 + 0.1
		disc.append(DISC_CENTER + Vector2(cos(angle), sin(angle)) * DISC_RADIUS)
	_details.draw_colored_polygon(disc, PartPickup.category_color(_part.category))

	var plate_width := _plate_label.get_minimum_size().x + 12.0
	_details.draw_rect(Rect2(TEXT_LEFT, 10.0, plate_width, 20.0), UiPalette.ACCENT_YELLOW)

	var shown_before_row := 0
	for row in STAT_NAMES.size():
		var bottom: float = STAT_ROW_CENTERS[row] + StatBar.BLOCK_HEIGHT * 0.5
		for i in StatBar.BLOCK_COUNT:
			var height: float = StatBar.BLOCK_HEIGHT + StatBar.HEIGHT_JITTER[i]
			var left := STAT_BLOCKS_LEFT + i * (StatBar.BLOCK_WIDTH + StatBar.BLOCK_GAP)
			var filled := i < _ratings[row] and shown_before_row + i < _blocks_shown
			_details.draw_rect(Rect2(left, bottom - height, StatBar.BLOCK_WIDTH, height),
					UiPalette.ACCENT_YELLOW if filled else UiPalette.STAT_EMPTY)
		shown_before_row += _ratings[row]

static func _ease_out_back(t: float) -> float:
	var overshoot := 1.70158
	return 1.0 + (overshoot + 1.0) * pow(t - 1.0, 3.0) + overshoot * pow(t - 1.0, 2.0)

static func _ease_in_back(t: float) -> float:
	var overshoot := 1.70158
	return (overshoot + 1.0) * t * t * t - overshoot * t * t
