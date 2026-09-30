extends Node
## The cutscene director (autoload `Cutscenes`). Plays a Cutscene as a movie:
## the player can't do anything but watch (Space moves the dialogue on, Esc
## skips the whole scene). Letterbox bars slide
## in over the HUD, the player's controls lock, the scene's script runs, then
## the camera eases back to the player and the bars slide out.
##
## Steps, all awaitable and skip-aware:
##   Camera  — cut_to, camera_to, camera_follow, shake
##   Screen  — fade_out, fade_in, title_card
##   Actors  — spawn_actor, walk, hop, fall_over, stand_up, face
##   Talk    — subtitle (typed in the bottom bar in the speaker's own voice,
##             moves on by itself; `{player}` becomes the player's name)
##   Misc    — wait, sound
##
## Actors are cleaned up when the cutscene ends. A cutscene's `gives_quest`
## goes into the quest log once the bars are gone. Which one-time scenes have
## played is saved (see `play_once()`, SaveSystem).

signal started
signal finished

const LAYER := 50
const BAR_HEIGHT_FRACTION := 0.13
const BAR_TIME := 0.45
const CAMERA_RETURN_TIME := 0.7
const CAMERA_FOLLOW_SPEED := 4.0
## Same size the junkyard dealer stands at in the world.
const ACTOR_SCALE := 0.55
## Subtitles stay up this long after they finish typing, plus a bit per letter.
const SUBTITLE_HOLD := 0.75
const SUBTITLE_HOLD_PER_LETTER := 0.02
## How fast subtitles type out.
const SUBTITLE_CHARACTERS_PER_SECOND := 55.0
## Advancing a tween this far finishes it outright; used to skip.
const SKIP_STEP_SECONDS := 1000.0

var _active: bool = false
var _skipping: bool = false
## Space was pressed: hurry the current subtitle along.
var _next_line_requested: bool = false
var _seen: Array[StringName] = []

var _layer: CanvasLayer
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _fade: ColorRect
var _title: Label
var _subtitle_name: Label
var _subtitle_line: Label
var _speech: SpeechPlayer

var _camera: Camera2D = null
var _original_camera: Camera2D = null
var _follow_target: Node2D = null
var _shake_strength: float = 0.0
var _shake_left: float = 0.0
var _actors: Array[CutsceneActor] = []
var _tweens: Array[Tween] = []

func _ready() -> void:
	_build_screen()
	_speech = SpeechPlayer.new()
	_speech.characters_per_second = SUBTITLE_CHARACTERS_PER_SECOND
	add_child(_speech)

func is_active() -> bool:
	return _active

func is_skipping() -> bool:
	return _skipping

# --- Running a cutscene ---------------------------------------------------------

func play(cutscene: Cutscene) -> void:
	if _active:
		push_warning("Cutscenes: already playing one, ignoring the new one.")
		return
	_active = true
	_skipping = false
	started.emit()
	Sfx.play(&"cutscene_whoosh", -6.0, 0.03)
	await _slide_letterbox(true)
	await cutscene.play()
	await _end()
	if cutscene.gives_quest != null:
		Quests.give(cutscene.gives_quest)

## Plays `cutscene` unless one with the same `id` already played on this save.
func play_once(cutscene: Cutscene) -> void:
	if cutscene.id.is_empty():
		push_warning("Cutscenes: play_once() needs a cutscene with an id.")
		return
	if _seen.has(cutscene.id):
		return
	_seen.append(cutscene.id)
	await play(cutscene)

func has_seen(id: StringName) -> bool:
	return _seen.has(id)

func get_seen() -> Array[StringName]:
	return _seen.duplicate()

func restore_seen(ids: Array[StringName]) -> void:
	_seen = ids.duplicate()

func clear_seen() -> void:
	_seen.clear()

func skip() -> void:
	if not _active or _skipping:
		return
	_skipping = true
	_speech.finish()
	for tween in _tweens:
		if tween.is_valid():
			tween.custom_step(SKIP_STEP_SECONDS)

func _end() -> void:
	_hide_subtitle()
	_title.visible = false
	_follow_target = null
	_shake_left = 0.0
	for actor in _actors:
		if is_instance_valid(actor):
			actor.queue_free()
	_actors.clear()
	await _restore_camera()
	if _fade.color.a > 0.0:
		_skipping = false
		await fade_in(0.4)
	Sfx.play(&"cutscene_whoosh", -9.0, 0.03).pitch_scale *= 1.2
	await _slide_letterbox(false)
	_skipping = false
	_active = false
	finished.emit()

# --- Steps: time and sound ----------------------------------------------------------

func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skipping:
		await get_tree().process_frame
		left -= get_process_delta_time()

## A one-shot, positional when `at` is given. Silent while skipping.
func sound(sound_name: StringName, volume_db: float = 0.0, at: Variant = null) -> void:
	if _skipping:
		return
	if at == null:
		Sfx.play(sound_name, volume_db)
	else:
		Sfx.play_at(sound_name, _position_of(at), volume_db)

# --- Steps: screen --------------------------------------------------------------------

func fade_out(seconds: float = 0.6) -> void:
	await _fade_to(1.0, seconds)

func fade_in(seconds: float = 0.6) -> void:
	await _fade_to(0.0, seconds)

## Big centred text ("MEANWHILE..."), popped in, held, then gone.
func title_card(text: String, seconds: float = 2.0) -> void:
	if _skipping:
		return
	_title.text = text
	_title.visible = true
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(0.4, 0.4)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title, "scale", Vector2.ONE, 0.35)
	Sfx.play(&"dialog_open", -6.0, 0.05)
	await _await_tween(tween)
	await wait(seconds)
	_title.visible = false

## A line from `speaker_name`, typed into the bottom bar in their voice.
## `actor` (optional) does the talking squash while it types. Moves on by
## itself once it has been up long enough to read. The line stays on screen
## until the next one replaces it (or the cutscene ends), so back-to-back
## lines flow into each other instead of blinking off in between.
func subtitle(speaker_name: String, character: CharacterData, line: String, actor: CutsceneActor = null) -> void:
	if _skipping:
		return
	_subtitle_name.text = speaker_name.to_upper()
	_subtitle_name.visible = true
	_subtitle_line.visible = true
	_speech.speak(_subtitle_line, PlayerProfile.fill(line), character)
	if is_instance_valid(actor):
		actor.talking = true
	_next_line_requested = false
	while _speech.is_typing() and not _skipping:
		if _next_line_requested:
			# First Space finishes the line; a second one moves on.
			_next_line_requested = false
			_speech.finish()
		await get_tree().process_frame
	if is_instance_valid(actor):
		actor.talking = false
	var left := SUBTITLE_HOLD + line.length() * SUBTITLE_HOLD_PER_LETTER
	while left > 0.0 and not _skipping and not _next_line_requested:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_next_line_requested = false

# --- Steps: camera ---------------------------------------------------------------------

## Jumps the camera straight to `target` (a Node2D or a Vector2), no easing.
func cut_to(target: Variant, zoom: float = 1.0) -> void:
	_follow_target = null
	var camera := _take_camera()
	if camera == null:
		return
	camera.global_position = _position_of(target)
	camera.zoom = Vector2.ONE * zoom

## Eases the camera to `target` (a Node2D or a Vector2) at `zoom`.
func camera_to(target: Variant, zoom: float = 1.0, seconds: float = 1.0) -> void:
	_follow_target = null
	var camera := _take_camera()
	if camera == null:
		return
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", _position_of(target), seconds)
	tween.tween_property(camera, "zoom", Vector2.ONE * zoom, seconds)
	await _await_tween(tween)

## Keeps the camera drifting after `target` until the next camera move.
func camera_follow(target: Node2D) -> void:
	if _take_camera() != null:
		_follow_target = target

## Rattles the camera for `seconds` without waiting for it to stop.
func shake(strength: float = 12.0, seconds: float = 0.4) -> void:
	if _skipping:
		return
	_shake_strength = strength
	_shake_left = seconds

# --- Steps: actors ----------------------------------------------------------------------

## A character standing at `at` in the current scene, Y-sorted with the rest
## of the world when there's a player car to sort alongside.
func spawn_actor(character: CharacterData, at: Vector2, facing_right: bool = true) -> CutsceneActor:
	var actor := CutsceneActor.new()
	actor.setup(character, ACTOR_SCALE)
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node
	var parent := car.get_parent() if car != null else get_tree().current_scene
	parent.add_child(actor)
	actor.global_position = at
	actor.face(facing_right)
	_actors.append(actor)
	return actor

func walk(actor: CutsceneActor, to: Vector2, speed: float = 160.0) -> void:
	await _await_tween(actor.walk_to(to, speed))

func hop(actor: CutsceneActor, height: float = 40.0) -> void:
	await _await_tween(actor.hop(height))

func fall_over(actor: CutsceneActor) -> void:
	await _await_tween(actor.fall_over())

func stand_up(actor: CutsceneActor) -> void:
	await _await_tween(actor.stand_up())

func face(actor: CutsceneActor, right: bool) -> void:
	actor.face(right)

# --- Internals ------------------------------------------------------------------------------

## Esc skips the whole cutscene; Space hurries the current subtitle along
## (finishes typing it, or moves on to the next line once it's all shown).
func _input(event: InputEvent) -> void:
	if not (_active and event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			skip()
		KEY_SPACE:
			get_viewport().set_input_as_handled()
			_next_line_requested = true

func _process(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	if _follow_target != null and is_instance_valid(_follow_target):
		_camera.global_position = _camera.global_position.lerp(
				_follow_target.global_position, 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta))
	if _shake_left > 0.0:
		_shake_left -= delta
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO

func _await_tween(tween: Tween) -> void:
	_tweens.append(tween)
	if _skipping:
		tween.custom_step(SKIP_STEP_SECONDS)
	if tween.is_running():
		await tween.finished
	_tweens.erase(tween)

func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await _await_tween(tween)

func _hide_subtitle() -> void:
	_subtitle_name.visible = false
	_subtitle_line.visible = false

## A cutscene camera parked exactly where the current one is looking, so
## taking over is seamless.
func _take_camera() -> Camera2D:
	if is_instance_valid(_camera):
		return _camera
	_original_camera = get_viewport().get_camera_2d()
	var scene := get_tree().current_scene
	if _original_camera == null or scene == null:
		return null
	_camera = Camera2D.new()
	scene.add_child(_camera)
	_camera.global_position = _original_camera.get_screen_center_position()
	_camera.zoom = _original_camera.zoom
	_camera.make_current()
	return _camera

func _restore_camera() -> void:
	if not is_instance_valid(_camera):
		_camera = null
		return
	if is_instance_valid(_original_camera):
		var return_time := 0.01 if _skipping else CAMERA_RETURN_TIME
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_camera, "global_position", _original_camera.get_screen_center_position(), return_time)
		tween.tween_property(_camera, "zoom", _original_camera.zoom, return_time)
		await tween.finished
		if is_instance_valid(_original_camera):
			_original_camera.make_current()
	_camera.queue_free()
	_camera = null
	_original_camera = null

static func _position_of(target: Variant) -> Vector2:
	if target is Node2D:
		return (target as Node2D).global_position
	return target

# --- Screen furniture ----------------------------------------------------------------------

func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.visible = false
	add_child(_layer)

	_top_bar = _make_rect(UiPalette.INK, 0.0, BAR_HEIGHT_FRACTION)
	_bottom_bar = _make_rect(UiPalette.INK, 1.0 - BAR_HEIGHT_FRACTION, 1.0)

	_subtitle_name = _make_label(UiPalette.ACCENT_YELLOW, 18)
	_subtitle_name.anchor_top = 0.08
	_subtitle_name.anchor_bottom = 0.38
	_bottom_bar.add_child(_subtitle_name)
	_subtitle_line = _make_label(UiPalette.TEXT_LIGHT, 22)
	_subtitle_line.anchor_top = 0.36
	_subtitle_line.anchor_bottom = 0.95
	_subtitle_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Left-aligned and laid out in full before it types, so the line reads left
	# to right in place instead of growing out from the middle, and a word
	# never jumps to the next row halfway through.
	_subtitle_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle_line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_subtitle_line.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_bottom_bar.add_child(_subtitle_line)
	_hide_subtitle()

	var hint := _make_label(UiPalette.TRIM_OFF_WHITE, 14)
	hint.text = "Space  next line      Esc  skip scene"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.anchor_left = 0.5
	hint.anchor_right = 0.98
	hint.anchor_top = 0.2
	hint.anchor_bottom = 0.8
	_top_bar.add_child(hint)

	_fade = _make_rect(Color(UiPalette.INK, 0.0), 0.0, 1.0)

	_title = _make_label(UiPalette.TEXT_LIGHT, 48)
	_title.anchor_top = 0.4
	_title.anchor_bottom = 0.6
	_title.visible = false
	_layer.add_child(_title)

func _make_rect(color: Color, anchor_top: float, anchor_bottom: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_right = 1.0
	rect.anchor_top = anchor_top
	rect.anchor_bottom = anchor_bottom
	_layer.add_child(rect)
	return rect

func _make_label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.1
	label.anchor_right = 0.9
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Bars slide in from off-screen top and bottom, and back out again.
func _slide_letterbox(show: bool) -> void:
	_layer.visible = true
	var hidden_offset := -_top_bar.size.y
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT if show else Tween.EASE_IN)
	var start := hidden_offset if show else 0.0
	var target := 0.0 if show else hidden_offset
	for property in ["offset_top", "offset_bottom"]:
		_top_bar.set(property, start)
		_bottom_bar.set(property, -start)
		tween.tween_property(_top_bar, property, target, BAR_TIME)
		tween.tween_property(_bottom_bar, property, -target, BAR_TIME)
	await tween.finished
	if not show:
		_layer.visible = false
