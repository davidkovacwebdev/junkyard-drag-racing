extends RefCounted
## Driving around town. A 5/4 swamp oom-pah (3+3+2+2) where a gargling blob
## sings the tune "hoo-ba ga-loo-ba" and a chipmunk gremlin shouts it back. The
## chorus falls down a staircase of major chords (Bb A Ab G Gb F), the tape
## plays a bar backwards, the radio fizzles, and a saucepan keeps bonking in
## threes against the fives.

static func compose() -> AudioStreamWAV:
	var verse_chords := ["Dm7", "Dm7", "Ebmaj7", "Ebmaj7", "Dm7", "Dm7", "Ab7", "G7"]
	var staircase_chords := ["Bb", "A", "Ab", "G", "Gb", "F", "E7", "A7"]
	var staircase_thirds := ["D4", "C#4", "C4", "B3", "Bb3", "A3", "G#3", "C#4"]
	var staircase_fifths := ["F5", "E5", "Eb5", "D5", "Db5", "C5", "B4", "E5"]

	var tune := [
		["D4 . F4 . A4 . . G4 F4 .", "hoo ba ga loo ba"],
		[". . . . . . . . . .", ""],
		["G4 . Bb4 . D5 . . C5 Bb4 .", "wob ble gob ble dob"],
		["G4>Eb4 - - - - . . . . .", "bloooh"],
		["D4 . F4 . A4 . . G4 F4 .", "hoo ba ga loo ba"],
		[". . . . . . . . . .", ""],
		["C5 . Eb5 . Gb5 . . Eb5 C5 .", "zoo bee zoo bee dah"],
		["B4 . . D5 . F5>G5 - - - -", "gum bo waaa"],
	]
	var shout_back := ". . . . . . A5 G5 F5 ."
	var wrong_shout_back := ". . . . . . A5 G#5 F5>C5 -"

	var song := MusicSynth.new(126.0, 28, 5, 2, 77)
	song.swing = 0.15
	song.detune_cents = 22.0
	song.tape_wow = [7.0, 6]
	song.sloppiness = 0.008

	# Verse twice: first the blob leads and the gremlin shouts back, then the
	# goofy voice leads and the blob gargles back.
	for verse_start in [0, 16]:
		var lead := &"blob" if verse_start == 0 else &"voice"
		var lead_transpose := -12 if verse_start == 0 else 0
		var answerer := &"gremlin" if verse_start == 0 else &"blob"
		var answer_transpose := 0 if verse_start == 0 else -24
		song.bass(&"tuba", verse_chords, "1 . . 5 . . 1 . 5 .", verse_start, 0.65)
		song.arpeggio(&"banjo", verse_chords, ". x . . x . . x . x", verse_start, 0.12, 3)
		for bar in tune.size():
			if tune[bar][1] != "":
				song.sing(lead, tune[bar][0], tune[bar][1], verse_start + bar, 0.65, lead_transpose)
		song.sing(answerer, shout_back, "ga loo ba", verse_start + 1, 0.4, answer_transpose)
		song.sing(answerer, wrong_shout_back, "ga loo boo", verse_start + 5, 0.4, answer_transpose)
		song.drums("k+h . h k+z . s+h . k+h z .", verse_start, 7, 0.55)
		song.play(&"drums", "k . n . n . n n x .", verse_start + 7, 0.55)
		song.loop(&"drums", "n . .", verse_start, 8, 0.18)

	# Staircase chorus: bwaa down the major chords, blob on bass, backwards bar.
	song.bass(&"blob", staircase_chords, "1 . . . . 5 . . 1 .", 8, 0.6)
	song.strum(&"organ", staircase_chords, "x - - - - x - - . .", 8, 0.18, 3)
	for bar in staircase_chords.size():
		var third: String = staircase_thirds[bar]
		var fifth: String = staircase_fifths[bar]
		song.sing(&"voice", "%s - - - - . . %s . ." % [third, third], "bwaaa dup", 8 + bar, 0.55, 12)
		song.sing(&"gremlin", ". . . . . %s . . %s ." % [fifth, fifth], "nyah nyah", 8 + bar, 0.3)
	song.drums("k . . s . k . s z z", 8, 8, 0.5)
	song.loop(&"drums", "q . . . . . .", 8, 8, 0.15)
	song.loop(&"bloop", "D5 . . A5 . . . F5", 12, 4, 0.25)

	# Stop-time wreck: hits, a bloop puddle, chipmunk laughter, the blob sinks.
	song.play(&"tuba", "D2 . . . . . D2 . . .", 24, 0.7)
	song.strum(&"organ", ["Dm7"], "x . . . . . x . . .", 24, 0.25, 3)
	song.sing(&"voice", "D5 . . . . . D5 . . .", "hup hey", 24, 0.6)
	song.play(&"drums", "k+t . . . . . k+t . . .", 24, 0.6)
	song.loop(&"bloop", "D5 A5 F5", 25, 1, 0.4)
	song.play(&"drums", "p . . p . . p . p p", 25, 0.5)
	song.sing(&"gremlin", "C5 C#5 D5 D#5 E5 F5 F#5 G5 G#5>A6 -", "hee hee hee hee hee hee hee hee heeee", 26, 0.4)
	song.play(&"drums", "k . . k . . k . k+x .", 26, 0.5)
	song.sing(&"blob", "G3>G2 - - - - - - - - -", "bloooorp", 27, 0.8)
	song.play(&"drums", "k . . . . . . . . .", 27, 0.5)

	song.stutter(3, 5, 1, 5)
	song.reverse(11, 0, 10)
	song.stutter(15, 6, 1, 4)
	song.crush(18, 0, 10)
	song.dropout(21, 6, 2)
	song.stutter(23, 5, 1, 5)
	song.tape_stop(27, 4, 6)
	return song.finish()
