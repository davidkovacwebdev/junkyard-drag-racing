extends RefCounted
## Menu. A goofy lounge singer who isn't quite a person scats "glup glup dupy
## doo" over chords that keep stepping on each other's toes (Cmaj7 → E7 →
## Abmaj7 → Db9), a chipmunk gremlin heckles, a gargling blob sings the bass,
## water-drop bloops drift against the beat, the tape skips, the radio breaks
## and the whole thing runs out of power at the end.

static func compose() -> AudioStreamWAV:
	var verse_chords := ["Cmaj7", "E7", "Abmaj7", "Db9", "Cmaj7", "E7", "F#7", "F7"]
	var bridge_chords := ["Ebmaj7", "Ebmaj7", "Am7", "D7", "Dbmaj7", "Dbmaj7", "Gaug7", "G7"]
	var bridge_roots := [3, 3, 9, 2, 1, 1, 7, 7]
	var breakdown_chords := ["Fm6", "Fm6", "Cmaj7", "Cmaj7", "Fm6", "Fm6", "Bb7", "G7"]

	var hook_bars := [
		["G4 . G4 . . . E4 G4 . A4 . G4>E4 - - . .", "glup glup du py doo waa"],
		["G#4 . B4 . D5 . . C5 B4 . G#4 . E4>E5 - - -", "bap ba dee ba doo bee wiii"],
		["C5 . Eb5 . G5 . . Eb5 . C5 . Ab4 . . . .", "blo bo bo ba ba boo"],
		["F5 - - Eb5 Db5 - B4 - . Ab4 . . F4>C4 - - -", "glaa ba doo bee dup blorp"],
		["G4 . G4 . . . E4 G4 . A4 . G4>E4 - - . .", "glup glup du py doo waa"],
		["G#4 . B4 . D5 . . C5 B4 . G#4 . E4>E5 - - -", "bap ba dee ba doo bee wiii"],
		["A#4 . A#4 . A#4 . C#5 . E5 - - - . . . .", "hup hup hup ba daa"],
		["A4 . Ab4 . G4 . F#4 . F4 . E4 . Eb4 . D4>C4 -", "doo doo doo doo doo doo doo glup"],
	]
	var heckle := ". . . . . . . . . . . . . E6 . E6"

	var song := MusicSynth.new(104.0, 32, 4, 4, 41)
	song.swing = 0.25
	song.detune_cents = 15.0
	song.tape_wow = [4.0, 5]
	song.sloppiness = 0.006

	# Verse, then the same verse three semitones up with the gremlin doubling.
	for verse_start in [0, 16]:
		song.key_shift = 0 if verse_start == 0 else 3
		song.bass(&"slap_bass", verse_chords, "1 . . 8 . . 5 . 1 . . 7 . 8 5 .", verse_start, 0.75)
		song.strum(&"clav", verse_chords, ". . x . . . x . . x . . . . x .", verse_start, 0.3, 4)
		for bar in hook_bars.size():
			song.sing(&"voice", hook_bars[bar][0], hook_bars[bar][1], verse_start + bar, 0.6)
			if verse_start == 16:
				song.sing(&"gremlin", hook_bars[bar][0], hook_bars[bar][1], verse_start + bar, 0.25, 12)
		song.sing(&"gremlin", heckle, "nee nee", verse_start, 0.3)
		song.sing(&"gremlin", heckle, "nyuk nyuk", verse_start + 4, 0.3)
		song.drums("k+h . h k+z . s+h . . k+h z . s+h p k . .", verse_start, 6, 0.55)
		song.play(&"drums", "k+h . . k . . k . . k . . n . n n | s . z . s . z . s s s s k+x . . .", verse_start + 6, 0.55)
		song.loop(&"drums", "w . . w . . .", verse_start, 8, 0.25)
		song.play(&"bloop", ". . . . . . . . . . . . C6 . G5 C5", verse_start + 3, 0.35)
	song.key_shift = 0

	# Bridge: blob on bass, scat call and response, bloops wandering in sevens.
	song.bass(&"blob", bridge_chords, "1 . . . . . 5 . 1 . . . 8 - 5 .", 8, 0.7)
	song.strum(&"organ", bridge_chords, "x - - - - - - - . . x - - - . .", 8, 0.18, 3)
	for bar in bridge_roots.size():
		song.loop(&"bloop", "C5 . . G5 . . C6", 8 + bar, 1, 0.3, bridge_roots[bar])
	song.sing(&"voice", "G4 . Bb4 . D5 - - . C5 . Bb4 . G4 - . . | . . . . . . . . . . . . . . . .", "shoo bee doo bee doo wop", 8, 0.6)
	song.sing(&"gremlin", ". . G5 . G5 . . . Bb5>G5 - - - . . . .", "nee nee wiii", 9, 0.35)
	song.sing(&"voice", "E4 . . A4 . C5 . E5 - - . D5 C5 . A4 .", "yab ba da boo ba dee blop", 10, 0.6)
	song.sing(&"voice", "F#4 . A4 . C5 . D5>F#5 - - - . . . . . .", "sha ba doo waaa", 11, 0.6)
	song.sing(&"gremlin", ". . . . . . . . . . . . D6 . C6 .", "yip yip", 11, 0.35)
	song.sing(&"voice", "F4 - - - Ab4 - - - C5 - - - Db5 - Eb5 - | F5 - - - - - - - - - - - . . . .", "hoo waa hoo lee la yoooo", 12, 0.6)
	song.sing(&"voice", "G4 . G4 . G4 . . . . . . . . . . .", "hup hup hup", 14, 0.6)
	song.sing(&"gremlin", ". . . . . . . . B5 . D6 . F6>G6 - - -", "ha ha haaa", 14, 0.3)
	song.sing(&"voice", "F4 . E4 . D4 . B3>G3 - - - . . . . . .", "da de do blooorp", 15, 0.6)
	song.drums("k . . z k . s . . z k . s . z z", 8, 8, 0.5)
	song.loop(&"drums", "h . p . h", 8, 8, 0.3)

	# Breakdown: half-time, the radio is broken, a yodel, the blob gets a solo.
	song.bass(&"tuba", breakdown_chords, "1 - - - . . . . 5 - - - . . . .", 24, 0.6)
	song.strum(&"organ", breakdown_chords, "x - - - - - - - - - - - . . x -", 24, 0.2, 3)
	song.drums("k . . . . . . . s . . . . . . z | k . . k . . . . s . . . . q . .", 24, 6, 0.5)
	var yodel_fm := "C5 - - - Ab4 - - - F4 - - - D5>C5 - - - | Ab4 - - - - - - - . . . . . . . ."
	song.sing(&"voice", yodel_fm, "ooh laa ee oh lay", 24, 0.6)
	song.sing(&"voice", "E5 - - - G5 - - - B5>C6 - - - - - - - | G5 - - - E5 - - - . . . . . . . .", "yo dl ay ee hoo", 26, 0.6)
	song.sing(&"voice", yodel_fm, "ooh laa ee oh lay", 28, 0.6)
	song.sing(&"gremlin", yodel_fm, "ooh laa ee oh lay", 28, 0.2, 12)
	song.sing(&"blob", "Bb2 . . D3 . . F3 . Ab3 . . F3 . D3 . .", "bu bu bu bu bu bu bu", 30, 0.8)
	song.play(&"drums", "k . . n . . n . n . . n . n n n", 30, 0.5)
	song.sing(&"voice", "G4>G5 - - - - - - - . . . . . . . .", "wheeee", 31, 0.6)
	song.play(&"drums", "k+x . . . . . . . . . . . . . . .", 31, 0.5)

	song.stutter(3, 12, 1, 4)
	song.stutter(7, 8, 2, 4)
	song.reverse(15, 8, 8)
	song.dropout(19, 8, 2)
	song.stutter(21, 0, 2, 3)
	song.crush(24, 0, 32)
	song.tape_stop(31, 8, 8)
	return song.finish()
