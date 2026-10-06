extends CanvasLayer
## Scene changes that would freeze the game (autoload "SceneLoader"). Puts up a
## loading board over a dimmed screen first, loads the next scene on a
## background thread while the board's tyre rolls along the progress blocks,
## then swaps scenes and takes the board down once the new scene has drawn.
##
## Building the new scene (instancing it and its `_ready()`s) has to happen on
## the main thread, so the board holds still for that last stretch; it's
## already up, so the game never looks hung. The old scene is paused and input
## swallowed while the board is up, so nothing drives off or opens mid-load.
##
## Use it for anything that enters or leaves gameplay. Hops between the light
## menu screens stay plain `change_scene_to_file()` calls, as they're instant.

const LAYER := 100
const BOARD_SIZE := Vector2(440.0, 190.0)
const OVERLAY_ALPHA := 0.5
const FADE_TIME := 0.12
## Share of the progress blocks the background load fills; the rest fills
## once the new scene is built.
const LOAD_SHARE := 0.75
## Shortest time the board stays up, so a quick load reads as a beat rather
## than a flicker.
const MIN_SHOW_TIME := 0.45

const QUIPS: Array[String] = [
	"Kicking the tyres...",
	"Hammering out the dents...",
	"Untangling the jumper cables...",
	"Sweeping up loose bolts...",
	"Duct-taping the map together...",
	"Waking up Grandpa...",
	"Hosing off the windshield...",
	"Bribing the tow truck...",
]

var _overlay: ColorRect
var _board: ScrapPanel
var _quip: Label
var _track: LoadingTrack
var _busy := false
var _shown_at_msec := 0

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func is_loading() -> bool:
	return _busy

func _input(_event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()

func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _show()
	var packed := await _load_in_background(path)
	if packed == null:
		push_error("SceneLoader: couldn't load %s" % path)
		get_tree().paused = false
		await _hide()
		return
	await _swap_to(packed)

func change_scene_packed(packed: PackedScene) -> void:
	if _busy:
		return
	_busy = true
	await _show()
	await _swap_to(packed)

func reload_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null and not scene.scene_file_path.is_empty():
		change_scene(scene.scene_file_path)

func _load_in_background(path: String) -> PackedScene:
	if ResourceLoader.has_cached(path):
		_track.progress = LOAD_SHARE
		return load(path)
	if ResourceLoader.load_threaded_request(path) != OK:
		return null
	var progress := []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(path)
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_track.progress = progress[0] * LOAD_SHARE
			_:
				return null
		await get_tree().process_frame
	return null

func _swap_to(packed: PackedScene) -> void:
	_track.progress = maxf(_track.progress, LOAD_SHARE)
	# Let the board draw at its latest fill before the build stalls the frame.
	await get_tree().process_frame
	await get_tree().process_frame
	# A paused tree stays paused across the change, so the new scene would
	# load frozen.
	get_tree().paused = false
	get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await get_tree().process_frame
	_track.progress = 1.0
	var remaining := MIN_SHOW_TIME - (Time.get_ticks_msec() - _shown_at_msec) / 1000.0
	await get_tree().create_timer(maxf(remaining, 0.25)).timeout
	await _hide()

func _show() -> void:
	_quip.text = QUIPS.pick_random()
	_track.reset()
	_overlay.color.a = 0.0
	_board.position.y = _board_rest_y()
	visible = true
	get_tree().paused = true
	_shown_at_msec = Time.get_ticks_msec()
	Sfx.play(&"loading_crank", -8.0, 0.05)
	_board.pivot_offset = _board.size * 0.5
	_board.scale = Vector2(0.9, 1.08)
	var tween := create_tween().set_parallel()
	tween.tween_property(_overlay, "color:a", OVERLAY_ALPHA, FADE_TIME)
	tween.tween_property(_board, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Two frames so the board is actually on screen before anything heavy runs.
	await get_tree().process_frame
	await get_tree().process_frame

func _hide() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_overlay, "color:a", 0.0, FADE_TIME)
	tween.tween_property(_board, "position:y", _board_rest_y() + 40.0, FADE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_board, "scale", Vector2(1.06, 0.0), FADE_TIME).set_delay(0.04)
	await tween.finished
	visible = false
	_busy = false

func _board_rest_y() -> float:
	return -BOARD_SIZE.y * 0.5

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var centre := Control.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(centre)

	_board = ScrapPanel.new()
	_board.tilt_degrees = -1.5
	_board.jitter_seed = 913
	_board.size = BOARD_SIZE
	_board.position = Vector2(-BOARD_SIZE.x * 0.5, _board_rest_y())
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_board)

	var title := _make_label("LOADING", 28, UiPalette.ACCENT_YELLOW)
	title.position = Vector2(0.0, 20.0)
	title.size = Vector2(BOARD_SIZE.x, 34.0)
	_board.add_child(title)

	_quip = _make_label("", 18, UiPalette.TEXT_LIGHT)
	_quip.position = Vector2(0.0, 58.0)
	_quip.size = Vector2(BOARD_SIZE.x, 26.0)
	_board.add_child(_quip)

	_track = LoadingTrack.new()
	_track.position = Vector2(48.0, 98.0)
	_track.size = Vector2(BOARD_SIZE.x - 96.0, 58.0)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_track)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
