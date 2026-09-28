extends SceneTree
## Bakes SongLibrary songs to sounds/music/<name>.wav so the game loads them
## instead of synthesizing at boot. By default only songs without a WAV yet are
## rendered, so existing bakes never change. Name songs to re-render them:
##   godot --headless --script res://tools/render_music.gd
##   godot --headless --script res://tools/render_music.gd -- glup_glup_dupy_doo
## then open the editor (or run `godot --headless --import`) to reimport.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SongLibrary.MUSIC_DIRECTORY))
	var requested := OS.get_cmdline_user_args()
	for song_name in SongLibrary.names():
		var wav_path := SongLibrary.baked_path(song_name)
		if requested.is_empty() and FileAccess.file_exists(wav_path):
			continue
		if not requested.is_empty() and not requested.has(String(song_name)):
			continue
		var started_msec := Time.get_ticks_msec()
		var stream := SongLibrary.render(song_name)
		var error := stream.save_to_wav(wav_path)
		if error != OK:
			push_error("render_music: saving %s failed (%s)" % [wav_path, error_string(error)])
			continue
		_write_import_settings(wav_path, stream)
		print("rendered %s (%.1f s) in %d ms" % [wav_path, stream.get_length(), Time.get_ticks_msec() - started_msec])
	quit()

## Keeps the loop through reimports: forward loop over the whole song.
func _write_import_settings(wav_path: String, stream: AudioStreamWAV) -> void:
	var import_path := wav_path + ".import"
	var config := ConfigFile.new()
	config.load(import_path)
	config.set_value("remap", "importer", "wav")
	config.set_value("remap", "type", "AudioStreamWAV")
	config.set_value("params", "edit/loop_mode", 2)
	config.set_value("params", "edit/loop_begin", 0)
	config.set_value("params", "edit/loop_end", stream.data.size() / 2)
	config.save(import_path)
