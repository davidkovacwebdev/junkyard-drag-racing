extends SceneTree
## Prints how loud every sound in the game is (LUFS, see Synth.loudness), for
## balancing the mix: each library sound raw and as Sfx plays it (after its
## level trim), every engine profile at idle and flat out (and the level_db
## that would put it at ENGINE_LOUDNESS), every character voice, and every
## song.
##   godot --headless --script res://tools/sound_level_probe.gd -- --no-save

const ENGINE_SECONDS := 2.0
## Where every engine's level_db puts it flat out.
const ENGINE_LOUDNESS := -11.0

func _initialize() -> void:
	for sound_name in SoundLibrary.NAMES:
		var samples := SoundLibrary.render(sound_name)
		var raw := Synth.loudness(samples)
		print("sfx %-28s raw %6.1f  played %6.1f  peak %6.1f" % [sound_name, raw, raw + SoundLibrary.level_trim_db(raw), _peak_db(samples)])
	for path in _files_in("res://sounds/engines/", ".tres"):
		var profile: EngineSoundProfile = load(path)
		var full := _engine_loudness(profile, 1.0, 1.0)
		print("engine %-30s idle %6.1f  full %6.1f  played %6.1f  suggested level_db %5.1f" % [path.get_file().get_basename(), _engine_loudness(profile, 0.0, 0.0), full, full + profile.level_db, snappedf(ENGINE_LOUDNESS - full, 0.5)])
	for path in _files_in("res://characters/", ".tres"):
		var character := load(path) as CharacterData
		if character == null:
			continue
		var voice := PackedFloat32Array()
		for stream: AudioStreamWAV in CharacterVoice.streams_for(character).values():
			voice.append_array(_samples_of(stream))
		print("voice %-26s %6.1f" % [path.get_file().get_basename(), Synth.loudness(voice)])
	for song_name in SongLibrary.names():
		var samples := _samples_of(SongLibrary.render(song_name))
		print("song %-27s %6.1f (400 ms %6.1f)" % [song_name, Synth.loudness(samples), Synth.loudness(samples, 0.4)])
	quit()

func _engine_loudness(profile: EngineSoundProfile, rpm: float, throttle: float) -> float:
	var voice := EngineVoice.new()
	voice.configure(profile, 1234)
	var samples := PackedFloat32Array()
	for frame in voice.synthesize(int(ENGINE_SECONDS * Synth.SAMPLE_RATE), rpm, throttle, 1.0):
		samples.append(frame.x)
	# Skip the first half second while the voice settles.
	return Synth.loudness(samples.slice(Synth.SAMPLE_RATE / 2), 1.0)

func _samples_of(stream: AudioStreamWAV) -> PackedFloat32Array:
	var data := stream.data
	var samples := PackedFloat32Array()
	samples.resize(data.size() / 2)
	for i in samples.size():
		samples[i] = data.decode_s16(i * 2) / 32768.0
	return samples

func _peak_db(samples: PackedFloat32Array) -> float:
	var loudest := 0.0
	for s in samples:
		loudest = maxf(loudest, absf(s))
	return linear_to_db(loudest)

func _files_in(dir_path: String, extension: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(extension):
			paths.append(dir_path + file)
	return paths
