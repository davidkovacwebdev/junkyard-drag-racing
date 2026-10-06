extends SceneTree
## Renders every SFX, song and a few engine runs to raw files and prints timings,
## for checking that a DSP change (GDScript or rust/) renders the same as before:
##   godot --headless --script res://tools/audio_parity_probe.gd -- <out_dir> --no-save

const ENGINE_PROFILES := ["engine_chainsaw", "engine_boiler", "engine_blender"]
const ENGINE_SEED := 1234
const ENGINE_FRAMES := 1764
const ENGINE_CHUNKS := 200

var _engine_usec := 0

func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)

	var started := Time.get_ticks_msec()
	for sound_name in SoundLibrary.NAMES:
		_save_floats("%s/sfx_%s.f32" % [out_dir, sound_name], SoundLibrary.render(sound_name))
	print("sfx: %d ms" % (Time.get_ticks_msec() - started))

	for song_name in SongLibrary.names():
		started = Time.get_ticks_msec()
		var stream := SongLibrary.render(song_name)
		var file := FileAccess.open("%s/song_%s.s16" % [out_dir, song_name], FileAccess.WRITE)
		file.store_buffer(stream.data)
		print("song %s: %d ms" % [song_name, Time.get_ticks_msec() - started])

	for profile_name in ENGINE_PROFILES:
		var profile: EngineSoundProfile = load("res://sounds/engines/%s.tres" % profile_name)
		started = Time.get_ticks_msec()
		var samples := _render_engine(profile)
		print("engine %s: %.1f ms synthesizing %.1f s of audio" % [profile_name, _engine_usec / 1000.0, float(ENGINE_FRAMES * ENGINE_CHUNKS) / Synth.SAMPLE_RATE])
		_save_floats("%s/engine_%s.f32" % [out_dir, profile_name], samples)
	quit()

func _render_engine(profile: EngineSoundProfile) -> PackedFloat32Array:
	_engine_usec = 0
	var voice := EngineVoice.new()
	voice.configure(profile, ENGINE_SEED)
	var out := PackedFloat32Array()
	for chunk in ENGINE_CHUNKS:
		var rpm := float(chunk) / ENGINE_CHUNKS
		var throttle := 1.0 if chunk % 40 < 20 else 0.0
		var chunk_started := Time.get_ticks_usec()
		var frames := voice.synthesize(ENGINE_FRAMES, rpm, throttle, 1.0)
		_engine_usec += Time.get_ticks_usec() - chunk_started
		for frame in frames:
			out.append(frame.x)
	return out

func _save_floats(path: String, samples: PackedFloat32Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(samples.to_byte_array())
