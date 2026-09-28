extends RefCounted
## Racing. Breakneck slap-bass blues in A: banjo spraying sixteenths, clav
## stabs, the kazoo tumbling down chromatic cascades, stop-time hits, a trash
## can drum solo — and the second lap goes up a semitone, because of course.

static func compose() -> AudioStreamWAV:
	var chords := ["A7", "A7", "A7", "A7", "D7", "D7", "A7", "A7", "E7", "D7", "A7", "E7"]
	var chord_transposes := [0, 0, 0, 0, 5, 5, 0, 0, 7, 5, 0, 7]
	var bass_riff := "A2 . A3 . . A2 C3 C#3 . E3 . G3 . A3 G3 E3"
	var bass_fill := "A2 . . A3 G3 . . F#3 F3 . E3 . Eb3 D3 C#3 C3"
	var hook := "E5 . . E5 . Eb5 D5 . C5 . A4 . . C5 . C#5"
	var hook_answer := "E5 - - . . . . . G5 . F#5 . F5 . E5 ."
	var cascade := "A5 . . G5 . . E5 . . Eb5 . D5 C#5 C5 B4 Bb4 | A4 - . . A4>A5 - - - . . . . . . . ."
	var stop_time := "A2 . . Bb2 . . B2 . . C3 . . C#3 . D3 D#3 | E3 . . . . . . . E3>E1 - - - . . . ."
	var bars_per_pass := 16

	var song := MusicSynth.new(148.0, bars_per_pass * 2, 4, 4, 3)
	song.swing = 0.1
	song.detune_cents = 10.0
	song.tape_wow = [2.0, 11]
	for pass_index in 2:
		var start := pass_index * bars_per_pass
		song.key_shift = pass_index
		for bar in chords.size():
			var riff := bass_fill if bar % 4 == 3 else bass_riff
			song.play(&"slap_bass", riff, start + bar, 0.8, chord_transposes[bar])
		song.arpeggio(&"banjo", chords, "1 3 5 7 8 7 5 3 1 3 5 7 8 7 5 3", start, 0.22)
		song.strum(&"clav", chords, "x . . x . . x . . . x . x . . .", start, 0.3, 4)
		song.drums("k+h . h k s+h . h z k+h z h k s+h . o .", start, chords.size(), 0.55)
		song.drums(". g . . . g . g . g . . . g . .", start, chords.size(), 0.4)

		song.play(&"slap_bass", stop_time, start + 12, 0.8)
		song.play(&"clav", stop_time, start + 12, 0.4, 24)
		song.play(&"kazoo", stop_time, start + 12, 0.35, 24)
		song.play(&"drums", "k+c . . k+c . . k+c . . k+c . . k+c . k k | k+t . . . . . . . . . . . b . . .", start + 12, 0.55)
		song.play(&"drums", "k t k t s t k . k k s . t t t t | s s z s s z s s k+t . . . o . b .", start + 14, 0.55)
		song.play(&"whistle", ". . . . . . . . A4>E6 - - - - - - -", start + 15, 0.3)

		var lead_instrument := &"kazoo" if pass_index == 0 else &"banjo"
		var lead_transpose := 0 if pass_index == 0 else 12
		song.play(lead_instrument, hook + "|" + hook_answer + "|" + hook + "|" + cascade.get_slice("|", 0), start, 0.5, lead_transpose)
		song.play(lead_instrument, hook + "|" + hook_answer, start + 4, 0.5, lead_transpose + 5)
		song.play(lead_instrument, cascade, start + 6, 0.5, lead_transpose)
		song.play(lead_instrument, hook, start + 8, 0.5, lead_transpose + 7)
		song.play(lead_instrument, hook, start + 9, 0.5, lead_transpose + 5)
		song.play(lead_instrument, cascade, start + 10, 0.5, lead_transpose)
		if pass_index == 1:
			song.play(&"kazoo", hook + "|" + hook_answer + "|" + hook + "|" + cascade.get_slice("|", 0), start, 0.3, -12)
			song.play(&"kazoo", cascade, start + 10, 0.3, -12)
	return song.finish()
