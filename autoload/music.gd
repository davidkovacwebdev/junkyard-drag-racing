extends Node
## Background music (autoload singleton "Music"). Picks a song for whatever
## scene is current and crossfades when that changes. Songs are prebaked WAVs
## (see tools/render_music.gd).

const VOLUME_DB := -8.0
const CROSSFADE_TIME := 1.5

var _songs: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _active_player := 0
var _playing_song: StringName = &""
var _fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = AudioSettings.MUSIC
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	for song_name in SongLibrary.NAMES:
		_songs[song_name] = load(SongLibrary.baked_path(song_name))

func _exit_tree() -> void:
	# A still-playing looping stream outlives the player at exit otherwise.
	for player in _players:
		player.stop()
		player.stream = null

func _process(_delta: float) -> void:
	var wanted := _song_for_scene(get_tree().current_scene)
	if wanted == &"" or wanted == _playing_song:
		return
	var stream: AudioStreamWAV = _songs.get(wanted)
	if stream != null:
		_crossfade_to(wanted, stream)

func _song_for_scene(scene: Node) -> StringName:
	if scene == null:
		return _playing_song
	var path := scene.scene_file_path
	if path.begins_with("res://scenes/menu/"):
		return SongLibrary.MENU
	if path.begins_with("res://scenes/race/"):
		return SongLibrary.RACE
	return SongLibrary.OVERWORLD

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
