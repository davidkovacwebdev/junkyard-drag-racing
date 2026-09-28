extends RefCounted
## Menu. Shuffling E minor funk strut. The groove slides down in semitones
## (C7 B7 Bb7 A7), then the whole band climbs a chromatic scale in threes
## against the four, a spring boings, and the bass dive-bombs back home.

static func compose() -> AudioStreamWAV:
	var groove_chords := ["Em7", "Em7", "Em7", "Em7", "A9", "A9", "Em7", "Em7"]
	var slide_chords := ["C7", "B7", "Bb7", "A7"]
	var slide_transposes := [-4, -5, -6, -7]
	var bass_riff := "E2 . . E3 . E2 G2 . A2 . Bb2 B2 . . D3 E3 | E2 . . E3 . E2 G2 . A2 . G2 . F#2 F2 E2 Eb2"
	var chromatic_climb := "E2 . . F2 . . F#2 . . G2 . . G#2 . . A2 | . A#2 . . B2 . . C3 . . C#3 . . D3 . D#3>E3"
	var dive_bomb := "E2 . . . . . . . . . . . E3>E1 - - -"
	var sequence := "G#5 . . F#5 . E5 . D5 - . B4 . . G#4 . ."
	var lead := "B4 . . B4 . A#4 B4 . D5 . . E5 . D5 B4 . | G4 . A4 . A#4 B4 . . . . E4 . . F4 F#4 G4 | " \
			+ "G#4 . A4 . . A#4 . B4 . . D5 . C#5 C5 B4 . | E5 - - - . . . . E4>E5 - - - . . . ."
	var bars_per_pass := 16

	var song := MusicSynth.new(100.0, bars_per_pass * 2, 4, 4, 1)
	song.swing = 0.35
	song.detune_cents = 12.0
	song.tape_wow = [3.0, 7]
	for pass_index in 2:
		var start := pass_index * bars_per_pass
		song.riff(&"slap_bass", bass_riff, start, [0, 0, 5, 0], 0.8)
		song.riff(&"slap_bass", bass_riff.get_slice("|", 0), start + 8, slide_transposes, 0.8)
		song.play(&"slap_bass", chromatic_climb, start + 12, 0.8)
		song.play(&"clav", chromatic_climb, start + 12, 0.4, 24)
		song.play(&"slap_bass", dive_bomb, start + 15, 0.8)

		song.strum(&"clav", groove_chords + slide_chords, ". . x . . x . x . . x . . x . .", start, 0.35, 4)
		song.drums("k+h . h z s+h . h k h z k+h . s+h z o k", start, 12, 0.55)
		song.drums(". . g . . g g . . g . . . g . g", start, 12, 0.5)
		song.play(&"drums", "k+t . . k . . k . . k . . k . . k | . k . . k . . k . . k . . k . c+t", start + 12, 0.55)
		song.play(&"drums", "k . z s z k . z s . b . c c c c | k . . . c . . . . . . . s s s s", start + 14, 0.55)
		song.play(&"whistle", ". . . . . . . . D5>B5 - - - B5>E5 - - -", start + 15, 0.3)

	song.riff(&"toy_piano", ". . . . . . . . . . B5 A#5 B5 . . D6 | . . . . C#6 . C6 . B5 . . . G5 . G#5 A5", 0, [0, 0, 5, 0], 0.4)
	song.riff(&"kazoo", sequence, 8, slide_transposes, 0.45)

	song.play(&"kazoo", lead, 16, 0.5)
	song.play(&"kazoo", lead.get_slice("|", 0) + "|" + lead.get_slice("|", 1), 20, 0.5, 5)
	song.play(&"kazoo", lead.get_slice("|", 2) + "|" + lead.get_slice("|", 3), 22, 0.5)
	song.riff(&"kazoo", sequence, 24, slide_transposes, 0.45)
	song.riff(&"toy_piano", sequence, 24, slide_transposes, 0.3)
	song.play(&"kazoo", chromatic_climb, 28, 0.4, 24)
	return song.finish()
