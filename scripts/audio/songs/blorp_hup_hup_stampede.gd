extends RefCounted
## Racing. A breakneck broken breakbeat in E where the singer barks "hup hup
## hey hup!" and "blorp-a-dorp-a-doo", a gremlin wails like a siren, and in the
## chorus the voice, gremlin and blob pass a "HUP!" around like a hot potato.
## Halfway the tape stalls and the whole band restarts a tritone higher,
## because nobody told them not to.

static func compose() -> AudioStreamWAV:
	var verse_chords := ["Em7", "Em7", "F7", "F7", "Em7", "Em7", "Bb7", "A7"]
	var verse_roots := [0, 0, 1, 1, 0, 0, 6, 5]
	var chorus_chords := ["C7", "C7", "F#7", "F#7", "C7", "C7", "Bb7", "B7"]
	var chorus_roots := [-4, -4, 2, 2, -4, -4, 6, 7]
	var bass_riff := "E2 . E3 . . E2 G2 . E2 . F2 . E3 . D3 B2"

	var verse_lines := [
		["E4 . E4 . . . G4 . E4 . . . . . . .", "hup hup hey hup"],
		[". . . . . . . . B4 . A4 . G4 . F#4>E4 -", "blorp a dorp a doo"],
		["F4 . F4 . . . A4 . F4 . . . . . . .", "hup hup hey hup"],
		[". . . . . . . . C5 . Bb4 . A4 . G4>F4 -", "glorp a gorp a goo"],
		["B4 . . B4 . . B4 . D5 . . E5 - - - -", "go go go gaa"],
		["G5 - F#5 - E5 - D5 - B4 - - - . . . .", "yee ha dee da doo"],
		["Bb4 . D5 . F5 . Ab5 . . . . . . . . .", "bip bop bap bup"],
		["A5>A4 - - - - - - - . . . . . . . .", "waaaah"],
	]
	var siren := "E6 . D6 . B5>E6 - - . . . . . . . . ."
	var chorus_shouts := ["hup", "hey", "hup", "ho", "hup", "hey", "hoo", "haa"]

	var song := MusicSynth.new(172.0, 32, 4, 4, 13)
	song.swing = 0.08
	song.detune_cents = 12.0
	song.tape_wow = [2.5, 9]
	song.sloppiness = 0.004

	for half_start in [0, 16]:
		song.key_shift = 0 if half_start == 0 else 6
		var verse_start: int = half_start
		var chorus_start: int = half_start + 8

		song.riff(&"slap_bass", bass_riff, verse_start, verse_roots, 0.8)
		song.arpeggio(&"banjo", verse_chords, "1 3 5 7 8 7 5 3 1 3 5 7 8 7 5 3", verse_start, 0.15)
		song.strum(&"clav", verse_chords, "x . . x . . . . x . x . . . . .", verse_start, 0.25, 4)
		for bar in verse_lines.size():
			song.sing(&"voice", verse_lines[bar][0], verse_lines[bar][1], verse_start + bar, 0.65)
			if half_start == 16:
				song.sing(&"gremlin", verse_lines[bar][0], verse_lines[bar][1], verse_start + bar, 0.22, 12)
		song.sing(&"gremlin", siren, "wee oo wee", verse_start + 1, 0.3)
		song.sing(&"gremlin", siren, "wee oo wee", verse_start + 3, 0.3, 1)
		song.drums("k . k . s . . k . k . . s . z . | k . . k s . k . . k s . . z s s", verse_start, 8, 0.6)
		song.loop(&"drums", "h . h h .", verse_start, 8, 0.35)

		song.riff(&"slap_bass", "E2 . . . . . . . E2 . E3 . E2 . . .", chorus_start, chorus_roots, 0.8)
		song.strum(&"organ", chorus_chords, "x . . . . . x . . . x - - - . .", chorus_start, 0.2, 3)
		for bar in chorus_chords.size():
			var root: int = chorus_roots[bar]
			song.sing(&"voice", "E4 . . . . . . . . . . . . . . .", chorus_shouts[bar], chorus_start + bar, 0.65, root)
			song.sing(&"gremlin", ". . . . E5 . . . . . . . . . . .", chorus_shouts[bar], chorus_start + bar, 0.35, root)
			song.sing(&"blob", ". . . . . . . . E2 . . E2 . . . .", "bom bom", chorus_start + bar, 0.7, root)
			song.play(&"bloop", ". . . . . . . . . . . . E5 G5 B5 E6", chorus_start + bar, 0.2, root)
		song.drums("k+t . . . s . . k . . k . s . . . | k+t . . . s . k k . . . . s z s z", chorus_start, 8, 0.6)
		song.loop(&"drums", "p . . q . . .", chorus_start + 4, 4, 0.2)

	song.key_shift = 0
	song.sing(&"blob", "E3>E2 - - - - - - - - - - - - - - -", "bloooorp", 31, 0.6, 6)

	song.stutter(3, 12, 1, 4)
	song.reverse(7, 8, 8)
	song.dropout(11, 4, 4)
	song.crush(12, 0, 16)
	song.stutter(15, 4, 2, 4)
	song.tape_stop(15, 12, 4)
	song.stutter(19, 12, 1, 4)
	song.reverse(23, 8, 8)
	song.crush(28, 0, 16)
	song.tape_stop(31, 8, 8)
	return song.finish()
