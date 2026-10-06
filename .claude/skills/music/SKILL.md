---
name: music
description: How the game's music is composed, versioned, rendered and played. Use whenever asked to write, change, remix, render or add a song, add a MusicSynth instrument or singer, or change which songs play where.
---

# Music

## Hard rules

- **Never delete or overwrite a song.** Not its recipe, not its WAV. A new take is a new file: `scripts/audio/songs/<name>_v2.gd` (or a new name), registered alongside the old one. Old songs stay in `SongLibrary.SONGS` and their WAVs stay in `sounds/music/`.
- **Never change existing instruments in a way that changes how old songs sound.** Add new instruments/params instead. Anything that consumes `_rng` must only do so on code paths old songs don't hit (e.g. `sloppiness > 0`), or old recipes stop rendering byte-identically.
- `tools/render_music.gd` only renders songs with no WAV yet. Re-rendering an existing song is only done when the user explicitly asks, by naming it.

## Style

Weird, funny, memorable. Not polite, not epic, not "children's YouTube". User feedback: songs were "way too regular" — go wild:
- Chords that shouldn't follow each other (Cmaj7 → E7 → Abmaj7 → Db9), chromatic staircases of major chords, tritone key changes mid-song.
- Odd meters (5/4 as 3+3+2+2, 7/8), polymeter loops (`loop()` with 3/5/7-step figures drifting against the bar).
- Half-broken beats that are broken on purpose: tape `stutter`, `reverse`, `dropout`, `crush`, `tape_stop` at phrase ends.
- Singers doing nonsense scat ("glup glup dupy doo", "hoo-ba ga-loo-ba", "hup hup hey hup"), call and response between the voice, gremlin and blob, yodel cracks, big bends.
- A repeated vocal hook so the song is memorable. Keep songs under ~80 s.

## Files

| File | What |
|---|---|
| `scripts/audio/songs/<name>.gd` | One recipe per song: `extends RefCounted`, a `##` description, `static func compose() -> AudioStreamWAV` |
| `scripts/audio/song_library.gd` | `SongLibrary.SONGS` registry (name → preloaded recipe) and the `MENU_PLAYLIST` / `OVERWORLD_PLAYLIST` / `RACE_PLAYLIST` |
| `scripts/audio/music_synth.gd` | `MusicSynth`: pattern sequencer, instruments, singers, tape edits. Pattern language is documented at the top |
| `rust/src/music_dsp.rs`, `rust/src/song_mix.rs` | Native `MusicDsp` (instrument, singer and drum sample loops) and `SongMix` (mix bus, tape edits, master). A new instrument is a `#[func]` here plus a `match` arm in `MusicSynth._render_note()`; rebuild with `cargo build` in `rust/` |
| `tools/render_music.gd` | Bakes songs to `sounds/music/<name>.wav` + loop import settings |
| `autoload/music.gd` | `Music` autoload: plays the scene group's playlist, crossfades into the next song as one ends |

## Adding a song

1. Write `scripts/audio/songs/<name>.gd`.
2. Add it to `SongLibrary.SONGS` and to one or more playlists (put new songs first so they're heard).
3. `godot --headless --script res://tools/render_music.gd` (renders only missing WAVs), then `godot --headless --import`.
4. Fix any `MusicSynth: bar has N steps` warnings — every `|`-separated bar must be exactly one bar long.
5. Update the Music line in the `sound-design` skill's coverage section. Ask the user to listen; don't try to judge by numbers alone.

To audition a recipe without registering it, load the script and call `compose()` from a throwaway headless script in the scratchpad.

## Toolbox

- Instruments: `slap_bass`, `clav`, `kazoo`, `banjo`, `tuba`, `toy_piano`, `whistle`, `organ` (detuned combo organ), `bloop` (water-drop "glup"), `drums`.
- Singers: `voice` (goofy lead, yodel cracks), `gremlin` (chipmunk heckler), `blob` (gargling bass with vocal fry). `sing(singer, pattern, "glup glup du py doo", bar)` gives each note the next syllable; `G4@glup` inline also works; chord helpers (`bass`, `strum`) fall back to the singer's default syllable ("da", "nee", "bom"). Syllables are spelled phonetically: onset consonants + vowel (`a aa e i ee o oo u y`, others glide first→last letter) + end consonants. All-consonant syllables ("mmm", "shh") sustain.
- Drums: `k s z c h o g t w b` plus `p` mouth pop, `q` squeaky toy, `n` saucepan bonk, `x` record scratch.
- Knobs: `swing`, `detune_cents`, `tape_wow`, `key_shift`, `sloppiness` (random timing slop).
- Structure: `play`, `riff` (one riff walked through transposes), `loop` (polymeter), `bass`/`strum`/`arpeggio` (follow chords), `drums`.
- Tape edits on the final mix: `stutter(bar, step, slice_steps, repeats)`, `tape_stop`, `reverse`, `dropout`, `crush` (bar, step, length_steps).

Singers render slowly (~20 s for a vocal-heavy 75 s song). That's fine; it's offline.
