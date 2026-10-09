extends CanvasLayer
## Grandpa's funeral (autoload `Funeral`). It's held exactly `DELAY_DAYS`
## in-game days after the player leaves the hospital ("Bad News"), whatever
## quest they're on. A board on the right edge of the screen counts down to
## it; the graveyard gate opens for it (GraveyardGate).
##
## When the time comes the board turns red and the player has
## `WINDOW_SECONDS` of real time to get to the graveyard: within
## `ARRIVE_DISTANCE` of its gate, or inside the cemetery. While it's on
## the minimap, the GPS and the board's arrow all point at the graveyard
## (`wants_graveyard()`). Make it and the funeral's attended: the countdown
## stops, the gate stays open, and driving in plays the ceremony
## (GrandpaGrave, FuneralCutscene). Once that's `held` he lies in his grave
## for good. Miss it and lightning strikes the car, Grandpa yells from above, the
## player dies (FuneralLightningCutscene), and the story winds back to the
## day he died: "Grandpa?" again, everything after it forgotten, the note and
## the nickel gone, the clock back to that morning, the car at the garage.
##
## Its state is saved (SaveSystem). The countdown pauses with the game
## (trunk, journal), and the strike waits for any cutscene or race to end.

const HOSPITAL_QUEST := &"hospital_visit"
const DELAY_DAYS := 3
const WINDOW_SECONDS := 180.0
const ARRIVE_DISTANCE := 700.0
## Ticks the last seconds away.
const TICK_FROM := 10
const CEMETERY_SCENE := "res://scenes/cemetery/cemetery.tscn"
const WORLD_SCENE := "res://scenes/world/main.tscn"
const RACE_SCENES_DIR := "res://scenes/race/"
const LIGHTNING_SCENE := "res://cutscenes/funeral_lightning.tres"
## The quest that starts with Grandpa gone, and everything after it that
## missing the funeral winds back.
const DEATH_QUEST := preload("res://quests/grandpa_missing.tres")
const AFTER_DEATH_QUESTS: Array[StringName] = [&"hospital_visit", &"junkyard_truth",
		&"read_grandpas_note", &"mattress_nickel", &"west_bridge"]
const AFTER_DEATH_ITEMS: Array[StringName] = [&"grandpas_note", &"old_nickel"]

const LAYER := 45
const BOARD_SIZE := Vector2(420.0, 58.0)
## The arrow on the board pointing at the graveyard, while it's time to go.
const ARROW_SIZE := 15.0
const MADE_IT_SECONDS := 4.0

## When it's held, in absolute game seconds (see `now()`). 0: not set yet.
var funeral_at: float = 0.0
var attended: bool = false
## The ceremony in the cemetery has been played (FuneralCutscene).
var held: bool = false
## Real seconds left to get to the graveyard once it's time. -1: not yet.
var window_left: float = -1.0

var _striking: bool = false
var _last_tick: int = -1
var _made_it_left: float = 0.0
var _board: ScrapPanel
var _label: Label
var _arrow: Polygon2D
var _flash: ColorRect
var _cover: ColorRect

func _ready() -> void:
	layer = LAYER
	_build()

## The game clock as one number: seconds since day 1 began.
static func now() -> float:
	return (DayNightCycle.day - 1) * DayNightCycle.DAY_LENGTH + DayNightCycle.time_of_day

## Whether a funeral is coming up (or under way) that hasn't been attended.
func is_scheduled() -> bool:
	return funeral_at > 0.0 and not attended

## Whether there's a funeral the graveyard gate stays open for: coming up,
## under way, or made it to but not yet driven in for.
func is_pending() -> bool:
	return funeral_at > 0.0 and not held

## Whether the ceremony plays on driving into the cemetery: it's time (or
## the player already made it) and it hasn't been held yet.
func is_ceremony_due() -> bool:
	return is_pending() and (attended or window_left >= 0.0)

## Whether everything should point the player at the graveyard right now.
func wants_graveyard() -> bool:
	return is_ceremony_due() and not _striking

## The ceremony is over (FuneralCutscene).
func hold() -> void:
	attended = true
	held = true
	window_left = -1.0
	_made_it_left = 0.0
	SaveSystem.save_game()

func reset() -> void:
	funeral_at = 0.0
	attended = false
	held = false
	window_left = -1.0
	_made_it_left = 0.0

## For SaveSystem.
func restore(saved_at: float, saved_attended: bool, saved_window_left: float,
		saved_held: bool = false) -> void:
	funeral_at = saved_at
	attended = saved_attended
	held = saved_held
	window_left = saved_window_left
	_made_it_left = 0.0

## Dev: holds it `seconds` from now (the F5 board).
func debug_start_in(seconds: float) -> void:
	attended = false
	held = false
	window_left = -1.0
	funeral_at = now() + seconds

func _process(delta: float) -> void:
	_update_countdown(delta)
	_update_board(delta)

func _update_countdown(delta: float) -> void:
	if attended or _striking:
		return
	if funeral_at <= 0.0:
		# A save from before the funeral existed: it's 3 days from now.
		if Quests.is_complete(HOSPITAL_QUEST):
			funeral_at = now() + DELAY_DAYS * DayNightCycle.DAY_LENGTH
		return
	if window_left < 0.0:
		if now() >= funeral_at:
			window_left = WINDOW_SECONDS
			_last_tick = -1
			Sfx.play(&"funeral_bell", -2.0, 0.0)
		return
	if _arrived():
		_attend()
		return
	window_left = maxf(window_left - delta, 0.0)
	var whole := ceili(window_left)
	if whole <= TICK_FROM and whole != _last_tick and whole > 0:
		_last_tick = whole
		Sfx.play(&"ui_hover", -2.0, 0.0)
	if window_left <= 0.0 and _can_strike():
		_strike()

## At the graveyard: inside the cemetery, or driving up to its gate.
func _arrived() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if scene.scene_file_path == CEMETERY_SCENE:
		return true
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null:
		return false
	for gate: Node2D in get_tree().get_nodes_in_group(GraveyardGate.GROUP):
		if car.global_position.distance_to(gate.global_position) <= ARRIVE_DISTANCE:
			return true
	return false

func _attend() -> void:
	attended = true
	window_left = -1.0
	_made_it_left = MADE_IT_SECONDS
	Sfx.play(&"funeral_bell", -2.0, 0.0)
	SaveSystem.save_game()

## Not mid-cutscene, mid-race or on a menu: somewhere the car can be hit.
func _can_strike() -> bool:
	var scene := get_tree().current_scene
	if scene == null or Cutscenes.is_active():
		return false
	var path := scene.scene_file_path
	return not path.begins_with(RACE_SCENES_DIR) and not path.begins_with("res://scenes/menu/")

func _strike() -> void:
	_striking = true
	var scene := ResourceLoader.load(LIGHTNING_SCENE, "", ResourceLoader.CACHE_MODE_REPLACE) as Cutscene
	if scene != null:
		await Cutscenes.play(scene)
	_rewind()
	SaveSystem.save_game()
	await SceneLoader.change_scene(WORLD_SCENE)
	# The black stays up until the garage is back on screen.
	var lift := create_tween()
	lift.tween_property(_cover, "color:a", 0.0, 0.8)
	lift.tween_callback(func() -> void: _cover.visible = false)
	Music.hush(false)
	_striking = false

## Back to the day Grandpa died, quest-wise.
func _rewind() -> void:
	var death_day := WorldState.crane_fell_day if WorldState.crane_fell_day > 0 else DayNightCycle.day
	Quests.rewind(AFTER_DEATH_QUESTS, DEATH_QUEST)
	for id in AFTER_DEATH_ITEMS:
		Inventory.remove_item(id)
	DayNightCycle.day = death_day
	DayNightCycle.time_of_day = DayNightCycle.START_TIME
	reset()
	WorldState.player_position = StoryDirector.OPENING_CAR_SPOT
	WorldState.has_player_position = true

## A white flash over everything (the lightning), fading straight off.
func flash() -> void:
	_flash.color.a = 1.0
	var fade := create_tween()
	fade.tween_property(_flash, "color:a", 0.0, 0.5)

## Black over everything until the world reloads (the strike's last beat).
func cover() -> void:
	_cover.color.a = 1.0
	_cover.visible = true

# --- The board -------------------------------------------------------------------

func _update_board(delta: float) -> void:
	_update_arrow()
	if not is_pending() or _striking or _in_cemetery():
		_board.visible = false
		return
	_board.visible = Journal.hud_allowed()
	if _made_it_left > 0.0:
		_made_it_left -= delta
		_label.text = "You made it! Drive in the gate"
		_style(false)
		return
	if attended:
		_label.text = "Grandpa's funeral: drive in the gate"
		_style(false)
		return
	if window_left >= 0.0:
		var seconds := ceili(window_left)
		_label.text = "FUNERAL NOW! To the graveyard  %d:%02d" % [seconds / 60, seconds % 60]
		_style(true)
		return
	var hours := (funeral_at - now()) / DayNightCycle.SECONDS_PER_HOUR
	var days := int(hours / 24.0)
	var left_hours := int(hours) % 24
	if days > 0:
		_label.text = "Grandpa's funeral in %dd %dh" % [days, left_hours]
	elif hours >= 1.0:
		_label.text = "Grandpa's funeral in %dh" % left_hours
	else:
		_label.text = "Grandpa's funeral in %dm" % maxi(1, int(hours * 60.0))
	_style(false)

## The ceremony plays the moment the cemetery loads; no board in there.
func _in_cemetery() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == CEMETERY_SCENE

## Points from the car to the graveyard gate, on the left end of the board.
func _update_arrow() -> void:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var gate := get_tree().get_first_node_in_group(GraveyardGate.GROUP) as Node2D
	_arrow.visible = wants_graveyard() and car != null and gate != null
	if _arrow.visible:
		_arrow.rotation = (gate.global_position - car.global_position).angle()

## Plain wood counting down; red once it's time to go.
func _style(urgent: bool) -> void:
	var body := UiPalette.DANGER_RED if urgent else UiPalette.SURFACE_BASE
	if _board.body_color == body:
		return
	_board.body_color = body
	_board.shade_color = body.darkened(0.2)
	_board.skirt_color = body.darkened(0.35)
	_label.add_theme_color_override("font_color", UiPalette.TEXT_LIGHT)

func _build() -> void:
	_board = ScrapPanel.new()
	_board.nails = false
	_board.tilt_degrees = -1.0
	_board.jitter_seed = 517
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.anchor_left = 1.0
	_board.anchor_right = 1.0
	_board.offset_left = -BOARD_SIZE.x - 20.0
	_board.offset_right = -20.0
	_board.offset_top = 64.0
	_board.offset_bottom = 64.0 + BOARD_SIZE.y
	_board.visible = false
	add_child(_board)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", UiPalette.TEXT_LIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Always one line: the board is sized for the longest text it shows.
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.clip_text = true
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = ARROW_SIZE * 2.0 + 14.0
	_label.offset_right = -ARROW_SIZE * 2.0 - 14.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_label)
	# A chunky chevron pointing right; turned toward the graveyard.
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([
		Vector2(ARROW_SIZE, 0.0), Vector2(-ARROW_SIZE * 0.8, -ARROW_SIZE * 0.85),
		Vector2(-ARROW_SIZE * 0.35, 0.0), Vector2(-ARROW_SIZE * 0.8, ARROW_SIZE * 0.85),
	])
	_arrow.color = UiPalette.ACCENT_YELLOW
	_arrow.position = Vector2(ARROW_SIZE + 14.0, BOARD_SIZE.y * 0.5)
	_arrow.visible = false
	_board.add_child(_arrow)
	_style(false)

	_flash = _full_screen(Color(1, 1, 1, 0))
	_cover = _full_screen(Color(UiPalette.INK, 0.0))
	_cover.visible = false

func _full_screen(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	return rect
