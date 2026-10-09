extends Node
## Background music (autoload singleton "Music"). Plays the SongLibrary
## playlist for whatever scene is current, crossfading when the scene group
## changes and from each song into the next as it ends. Songs are prebaked WAVs
## (see tools/render_music.gd).

const VOLUME_DB := -8.0
const CROSSFADE_TIME := 1.5

var _songs: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _active_player := 0
var _playing_song: StringName = &""
var _playing_playlist: Array[StringName] = []
var _next_index_by_playlist: Dictionary = {}
var _fade_tween: Tween
## Set by `hush()`: no music at all until it's lifted.
var _hushed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = AudioSettings.MUSIC
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	for song_name in SongLibrary.names():
		if ResourceLoader.exists(SongLibrary.baked_path(song_name)):
			_songs[song_name] = load(SongLibrary.baked_path(song_name))

func _exit_tree() -> void:
	# A still-playing looping stream outlives the player at exit otherwise.
	for player in _players:
		player.stop()
		player.stream = null

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or _hushed:
		return
	var wanted_playlist := _playlist_for_scene(scene)
	if wanted_playlist != _playing_playlist:
		_playing_playlist = wanted_playlist
		_play_next_from_playlist()
	elif _current_song_is_ending():
		_play_next_from_playlist()

## Fades the music out for a scene that wants quiet (bad news, a morgue),
## or, with false, brings the scene's playlist back in.
func hush(on: bool, seconds: float = CROSSFADE_TIME) -> void:
	if on == _hushed:
		return
	_hushed = on
	if not on:
		# Forget what was playing, so _process starts the playlist afresh.
		_playing_playlist = []
		_playing_song = &""
		return
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel()
	for player in _players:
		if player.playing:
			_fade_tween.tween_property(player, "volume_db", -80.0, seconds)
	_fade_tween.chain().tween_callback(func() -> void:
		for player in _players:
			player.stop())

func _playlist_for_scene(scene: Node) -> Array[StringName]:
	var path := scene.scene_file_path
	if path.begins_with("res://scenes/menu/"):
		return SongLibrary.MENU_PLAYLIST
	if path.begins_with("res://scenes/race/"):
		return SongLibrary.RACE_PLAYLIST
	return SongLibrary.OVERWORLD_PLAYLIST

func _current_song_is_ending() -> bool:
	var player := _players[_active_player]
	if not player.playing or player.stream == null or _playing_playlist.size() < 2:
		return false
	return player.get_playback_position() >= player.stream.get_length() - CROSSFADE_TIME

## Starts the playlist's next song. Each playlist remembers where it got to, so
## coming back to a scene group moves on to a song not heard last time.
func _play_next_from_playlist() -> void:
	var key := str(_playing_playlist)
	var index: int = _next_index_by_playlist.get(key, 0)
	for attempt in _playing_playlist.size():
		var song_name := _playing_playlist[(index + attempt) % _playing_playlist.size()]
		var stream: AudioStreamWAV = _songs.get(song_name)
		if stream == null:
			continue
		_next_index_by_playlist[key] = (index + attempt + 1) % _playing_playlist.size()
		if song_name != _playing_song:
			_crossfade_to(song_name, stream)
		return

func _crossfade_to(song_name: StringName, stream: AudioStreamWAV) -> void:
	_playing_song = song_name
	var outgoing := _players[_active_player]
	_active_player = 1 - _active_player
	var incoming := _players[_active_player]
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(incoming, "volume_db", VOLUME_DB, CROSSFADE_TIME)
	if outgoing.playing:
		_fade_tween.tween_property(outgoing, "volume_db", -80.0, CROSSFADE_TIME)
		_fade_tween.chain().tween_callback(outgoing.stop)
