extends RefCounted
## "Dig Dug Montage": five seconds of the most generic rock there is, for the
## digger's reveal montage (DiggerRevealCutscene). Organ power chords chugging
## E5 - G5 - A5 - C5/D5 at 150 BPM over a slap bass hammering eighths and
## straight-ahead rock drums, the kazoo doing its very best guitar solo
## (bends and all), and the gang yelling "DIG!" on the turnaround. Every
## cliche, nothing clever. Not on a playlist: played once, cut off at 5 s.

static func compose() -> AudioStreamWAV:
	var chords := ["E5", "G5", "A5", "D5"]
	var bar_count := 4
	var song := MusicSynth.new(150.0, bar_count, 4, 2, 21)
	song.swing = 0.0
	song.detune_cents = 12.0
	song.sloppiness = 0.006

	for bar in bar_count:
		song.strum(&"organ", [chords[bar]], "x . x x . x x x", bar, 0.45)
		song.bass(&"slap_bass", [chords[bar]], "1 1 1 1 1 1 8 1", bar, 0.7)
	song.drums("k+o h s+h h k+h k+h s+h h", 0, 1, 0.7)
	song.drums("k+h h s+h h k+h k+h s+h h", 1, 2, 0.7)
	song.drums("s s s+k s k+s k+s k+s+t o", 3, 1, 0.7)

	# The "guitar" solo.
	song.play(&"kazoo", "E5 . G5 A5 . A5>B5 - -", 0, 0.55)
	song.play(&"kazoo", "D6 B5 A5 G5 A5 - B5>E6 -", 1, 0.55)
	song.play(&"kazoo", "E6 - D6 B5 A5 G5 A5 -", 2, 0.55)
	song.play(&"kazoo", "G5 . E5 . . . . .", 3, 0.5)
	for singer: StringName in [&"voice", &"blob"]:
		song.play(singer, ". . . . E4@dig . E4@dig G4@dig", 3, 0.5, -12 if singer == &"blob" else 0)
	return song.finish()
