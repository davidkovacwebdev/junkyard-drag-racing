extends Node
## Plays the game's synthesized sound effects (autoload singleton "Sfx"). Every
## sound is rendered from code by SoundLibrary the first time it's asked for and
## cached; a background task pre-renders the whole library at boot so the first
## play of anything doesn't stall a frame.
##
## Lives above the scenes, so a sound started right before a scene change (a
## door slamming as you enter a building) carries on through it. Every Button
## in the game clicks through here too — see `_on_node_added`.

const POOL_SIZE := 12
const UI_CLICK_VOLUME_DB := -8.0

var _cache: Dictionary = {}
var _cache_mutex := Mutex.new()
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _prerender_task := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_prerender_task = WorkerThreadPool.add_task(_prerender_all)
	get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	if _prerender_task != -1:
		WorkerThreadPool.wait_for_task_completion(_prerender_task)
		_prerender_task = -1

## The rendered stream for a SoundLibrary name. Renders on the spot if the
## background task hasn't reached it yet.
func stream(sound_name: StringName) -> AudioStreamWAV:
	_cache_mutex.lock()
	var cached: AudioStreamWAV = _cache.get(sound_name)
	_cache_mutex.unlock()
	if cached != null:
		return cached
	var rendered := SoundLibrary.build_stream(sound_name)
	_cache_mutex.lock()
	_cache[sound_name] = rendered
	_cache_mutex.unlock()
	return rendered

## Non-positional one-shot (UI, pickups, anything "in your ears"). A little
## random pitch keeps repeats — a stream of scrap orbs — from sounding robotic.
## `bus` overrides the sound's usual bus (the settings screen previews each
## slider's level through it).
func play(sound_name: StringName, volume_db: float = 0.0, pitch_variation: float = 0.05, bus: StringName = &"") -> AudioStreamPlayer:
	var player := _free_player()
	player.stream = stream(sound_name)
	player.bus = bus if bus != &"" else SoundLibrary.bus_for(sound_name)
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
	return player

## Positional one-shot at a world position in the current scene, so it pans and
## fades with the camera. Falls back to `play()` when there's no scene to put
## it in.
func play_at(sound_name: StringName, global_position: Vector2, volume_db: float = 0.0, pitch_variation: float = 0.05) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		play(sound_name, volume_db, pitch_variation)
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream(sound_name)
	player.bus = SoundLibrary.bus_for(sound_name)
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.max_distance = 2500.0
	scene.add_child(player)
	player.global_position = global_position
	player.finished.connect(player.queue_free)
	player.play()

## An idle pool player, or the one that's been playing longest if all are busy.
func _free_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var player := _players[(_next_player + i) % POOL_SIZE]
		if not player.playing:
			_next_player = (_next_player + i + 1) % POOL_SIZE
			return player
	var oldest := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	return oldest

func _prerender_all() -> void:
	for sound_name in SoundLibrary.NAMES:
		_cache_mutex.lock()
		var done := _cache.has(sound_name)
		_cache_mutex.unlock()
		if not done:
			stream(sound_name)

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(_play_ui_click):
		(node as BaseButton).pressed.connect(_play_ui_click)

func _play_ui_click() -> void:
	play(&"ui_click", UI_CLICK_VOLUME_DB)
