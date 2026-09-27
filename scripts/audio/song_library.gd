class_name SongLibrary
extends RefCounted
## Every song in the game and which scenes play it. Each song is its own recipe
## file in scripts/audio/songs/ with a `static func compose() -> AudioStreamWAV`
## (see MusicSynth for the pattern language). Songs are never deleted or
## rewritten: a new take on a song is a new file (e.g. `junkyard_strut_v2.gd`).
## Songs are baked to WAV files by tools/render_music.gd.

const SONGS := {
	&"junkyard_strut": preload("res://scripts/audio/songs/junkyard_strut.gd"),
	&"drunk_crane_shuffle": preload("res://scripts/audio/songs/drunk_crane_shuffle.gd"),
	&"scrapheap_stampede": preload("res://scripts/audio/songs/scrapheap_stampede.gd"),
	&"glup_glup_dupy_doo": preload("res://scripts/audio/songs/glup_glup_dupy_doo.gd"),
	&"goblin_gumbo_wobble": preload("res://scripts/audio/songs/goblin_gumbo_wobble.gd"),
	&"blorp_hup_hup_stampede": preload("res://scripts/audio/songs/blorp_hup_hup_stampede.gd"),
}

## Songs per scene group, played in order; each one hands over to the next when
## it ends.
const MENU_PLAYLIST: Array[StringName] = [&"glup_glup_dupy_doo", &"junkyard_strut"]
const OVERWORLD_PLAYLIST: Array[StringName] = [&"goblin_gumbo_wobble", &"drunk_crane_shuffle"]
const RACE_PLAYLIST: Array[StringName] = [&"blorp_hup_hup_stampede", &"scrapheap_stampede"]

const MUSIC_DIRECTORY := "res://sounds/music"

static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(SONGS.keys())
	return out

static func baked_path(song_name: StringName) -> String:
	return "%s/%s.wav" % [MUSIC_DIRECTORY, song_name]

static func render(song_name: StringName) -> AudioStreamWAV:
	if not SONGS.has(song_name):
		push_error("SongLibrary: unknown song '%s'" % song_name)
		return null
	return SONGS[song_name].compose()
