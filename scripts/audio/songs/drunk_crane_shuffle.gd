extends RefCounted
## Driving around town. A drunk carnival stagger in 7/8 (2+2+3): tuba and slap
## bass lurching in D minor, lopsided clav, a melody that keeps sliding off
## the edge by a semitone, and whole-tone plinks when it falls over.

static func compose() -> AudioStreamWAV:
	var chords := ["Dm", "Dm", "Dm", "Dm", "G7", "G7", "Dm", "Dm",
			"Eb7", "Eb7", "A7", "A7", "Dm", "Dm", "Bb7", "A7"]
	var chord_transposes := [0, 0, 0, 0, 5, 5, 0, 0, 1, 1, 7, 7, 0, 0, 8, 7]
	var stagger := "D2 . D3 C3 . A2 G#2 | D2 . F2 F#2 G2 . G#2>A2"
	var opening := "A4 G#4 A4 . F5 . E5 | D5 - C#5 C5 B4 Bb4 A4"
	var answer := "D5 . F5 . G#5 . A5 | A5>D5 - - . . . ."
	var turnaround := "Bb4 A4 Ab4 . F4 . D4 | C#5 . E5 . G5 . Bb5"
	var whole_tone_fall := "C6+E6 A#5+D6 G#5+C6 F#5+A#5 E5+G#5 D5+F#5 C5+E5"
	var bars_per_pass := 16

	var song := MusicSynth.new(240.0, bars_per_pass * 2, 7, 1, 2)
	song.detune_cents = 25.0
	song.tape_wow = [6.0, 9]
	for pass_index in 2:
		var start := pass_index * bars_per_pass
		var bass_instrument := &"tuba" if pass_index == 0 else &"slap_bass"
		for bar in bars_per_pass:
			song.play(bass_instrument, stagger.get_slice("|", bar % 2), start + bar, 0.8, chord_transposes[bar])
		song.strum(&"clav", chords, ". x . x . x x", start, 0.3, 4)
		song.drums("k+h h s+h k h s+h g | k+h h s+h k h s+h g | k+h h s+h k h s+h g | k+h h s+h k+b . c c", start, bars_per_pass, 0.5)

	for pass_index in 2:
		var start := pass_index * bars_per_pass
		var instrument := &"toy_piano" if pass_index == 0 else &"kazoo"
		var transpose := 12 if pass_index == 0 else 0
		song.play(instrument, opening + "|" + answer, start, 0.5, transpose)
		song.play(instrument, opening, start + 4, 0.5, transpose + 5)
		song.play(instrument, answer, start + 6, 0.5, transpose)
		song.play(instrument, opening, start + 8, 0.5, transpose + 1)
		song.play(instrument, opening, start + 10, 0.5, transpose + 7)
		song.play(instrument, answer, start + 12, 0.5, transpose)
		song.play(instrument, turnaround, start + 14, 0.5, transpose)
	song.play(&"toy_piano", opening + "|" + answer, bars_per_pass, 0.2, 24)
	song.play(&"toy_piano", whole_tone_fall, bars_per_pass * 2 - 1, 0.35)
	song.play(&"whistle", ". . . . C6>F5 - -", bars_per_pass - 1, 0.25)
	return song.finish()
