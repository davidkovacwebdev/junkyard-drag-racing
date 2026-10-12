extends RefCounted
## "Bonk Club": a stadium chant in 5/4 (3+3+2+2) at 200 BPM. The whole gang
## sings it as one crowd (voice in the middle, gremlin an octave up, blob an
## octave down, smeared by sloppiness): "bonk, bonk, klub, hey!" Every other
## bar is a band stab, then the cable gets kicked out and the crowd answers
## "hup hup hup hoo" into the silence. Bars 5-7 walk the chant down a
## chromatic staircase of dominant chords, and the last bar sucks itself
## backwards into the top. Race playlist, and Chad's ringtone.

static func compose() -> AudioStreamWAV:
	var chords := ["Cmaj7", "E7", "Abmaj7", "Db9", "B7", "Bb7", "A7", "G7#9"]
	var chant := "G4@bonk . G4@bonk . E4@klub - - . C5@hey ."
	var answer_one := ". . . . . . B4@hup B4@hup G#4@hup E5>G#5@hoo"
	var chant_two := "Ab4@bonk . Ab4@bonk . Eb4@klub - - . C5@hey ."
	var answer_two := ". . . . . . Ab4@hup Ab4@hup F4@hup Eb5>Ab5@hoo"
	var finale := "D4@bonk D4@bonk D4@bonk D4@bonk G4@hey - - - - ."
	var stomp := "k+n . h k+n . h k+c . k+c t"
	var stab := "k+c+t . . . . . x . s s"
	var tuba_line := "1 . . 1 . . 5 . 8 ."
	var bar_count := 8

	var song := MusicSynth.new(200.0, bar_count, 5, 2, 9)
	song.swing = 0.0
	song.detune_cents = 20.0
	song.tape_wow = [2.0, 4]
	song.sloppiness = 0.012

	# The gang: three singers on one line, an octave apart.
	var gang := {&"voice": 0, &"gremlin": 12, &"blob": -12}
	for singer: StringName in gang:
		var octave: int = gang[singer]
		var gain := 0.55 if singer == &"voice" else 0.4
		song.play(singer, chant, 0, gain, octave)
		song.play(singer, answer_one, 1, gain, octave)
		song.play(singer, chant_two, 2, gain, octave)
		song.play(singer, answer_two, 3, gain, octave)
		song.riff(singer, chant, 4, [-1 + octave, -2 + octave, -3 + octave], gain)
		song.play(singer, finale, 7, gain, octave)

	# Band stabs on bars 2 and 4, the tuba thumping the root under them.
	for bar in [1, 3]:
		for instrument: StringName in [&"clav", &"organ", &"toy_piano"]:
			song.strum(instrument, [chords[bar]], "x . . . . . . . . .", bar, 0.35)
		song.bass(&"tuba", [chords[bar]], "1 . . . . . . . . .", bar, 0.7)
	for bar in [0, 2, 4, 5, 6, 7]:
		song.bass(&"tuba", [chords[bar]], tuba_line, bar, 0.7)
	# Slap bass doubles the staircase so it hits harder.
	song.bass(&"slap_bass", chords.slice(4), tuba_line, 4, 0.6)
	# A 7-step bloop drifting against the 10-step bar the whole way.
	song.loop(&"bloop", "C6 . . G5 . E6 .", 0, bar_count, 0.25)

	for bar in [0, 2, 4, 5, 6]:
		song.drums(stomp, bar, 1, 0.6)
	for bar in [1, 3]:
		song.drums(stab, bar, 1, 0.6)
	song.drums("k+c . k+c . k+c . k+c+t . b q", 7, 1, 0.6)

	# The cable gets kicked right after each stab; the crowd answers into it.
	song.dropout(1, 1, 5)
	song.dropout(3, 1, 5)
	song.stutter(6, 8, 1, 2)
	song.reverse(7, 8, 2)
	return song.finish()
