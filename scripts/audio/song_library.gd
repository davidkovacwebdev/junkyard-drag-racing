class_name SongLibrary
extends RefCounted
## The game's music, composed in code for MusicSynth (see there for the pattern
## language). Junkyard funk: syncopated slap bass, clav stabs, ghost notes,
## chromatic runs that go somewhere they shouldn't, a kazoo that won't behave.
## Silly, never epic. Each song loops.

const MENU := &"junkyard_strut"
const OVERWORLD := &"drunk_crane_shuffle"
const RACE := &"scrapheap_stampede"

const NAMES: Array[StringName] = [MENU, OVERWORLD, RACE]

static func render(song_name: StringName) -> AudioStreamWAV:
	match song_name:
		MENU: return _junkyard_strut()
		OVERWORLD: return _drunk_crane_shuffle()
		RACE: return _scrapheap_stampede()
	push_error("SongLibrary: unknown song '%s'" % song_name)
	return null

## Menu. Shuffling E minor funk strut. The groove slides down in semitones
## (C7 B7 Bb7 A7), then the whole band climbs a chromatic scale in threes
## against the four, a spring boings, and the bass dive-bombs back home.
static func _junkyard_strut() -> AudioStreamWAV:
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

## Driving around town. A drunk carnival stagger in 7/8 (2+2+3): tuba and slap
## bass lurching in D minor, lopsided clav, a melody that keeps sliding off
## the edge by a semitone, and whole-tone plinks when it falls over.
static func _drunk_crane_shuffle() -> AudioStreamWAV:
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

## Racing. Breakneck slap-bass blues in A: banjo spraying sixteenths, clav
## stabs, the kazoo tumbling down chromatic cascades, stop-time hits, a trash
## can drum solo — and the second lap goes up a semitone, because of course.
static func _scrapheap_stampede() -> AudioStreamWAV:
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
