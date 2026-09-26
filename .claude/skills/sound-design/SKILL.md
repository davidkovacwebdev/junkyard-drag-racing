---
name: sound-design
description: How sound works in this game and the rule that every new feature gets a fitting sound. Use whenever adding or changing a gameplay feature, interaction, UI screen, vehicle part, pickup, prop or weather/ambient effect, and whenever asked to add, change or tune a sound.
---

# Sound Design

## The rule

**Every feature that the player does, sees happen, or interacts with gets a sound, if a sound makes sense.** When you add a feature, add its sound in the same change without being asked, and mention it in your report. Ask yourself:

- Does the player press something? → feedback sound (UI buttons are already automatic).
- Does something hit, break, open, close, land, spawn or get collected? → one-shot.
- Is something ongoing (motor, rain, horn, skid, fire)? → sustained loop whose level follows the state.
- Does it succeed or fail? → reward sound vs `denied`.
- New engine part? → it needs an engine sound profile (see below).

Skip sound only for things that are purely visual and passive (a decal, a tint change) or would fire so often it becomes noise. If unsure, add it quieter rather than not at all.

## No audio files

Every sound is synthesized from code — do not add .wav/.ogg files. The toolkit is a GDScript port of a Lua car-sound synth:

| File | What it is |
|---|---|
| `scripts/audio/synth.gd` | `Synth` — DSP toolkit: curves, `engine()`, `tones()`, `noise_sweep()`, `thump()`, filters (`LowPass`, `HighPass`, `Formant`), `finish()`, `mix_into()`, `concat()`, `to_stream()` |
| `scripts/audio/sound_library.gd` | `SoundLibrary` — every named one-shot/loop and its builder |
| `autoload/sfx.gd` | `Sfx` autoload — renders + caches streams (pre-renders on a background thread), `play()`, `play_at()`, `stream()`, auto-clicks every `BaseButton` |
| `scripts/audio/sustained_sound.gd` | `SustainedSound` — a looping library sound driven by `set_level()` / `set_active()` with fades |
| `scripts/audio/engine_sound.gd` | `EngineSound` — live engine synth (AudioStreamGenerator) driven by `rpm` and `throttle` |
| `scripts/audio/engine_sound_profile.gd` | `EngineSoundProfile` — per-engine voice settings |
| `scripts/audio/music_synth.gd` | `MusicSynth` — music sequencer (text patterns, chord-following bass/strum/arpeggio) + instruments: slap bass, clav, kazoo, banjo, tuba, toy piano, slide whistle, junk drums (incl. ghost snare, clap, chicken scratch, trash lid, boing) |
| `scripts/audio/song_library.gd` | `SongLibrary` — the songs, composed in code |
| `autoload/music.gd` | `Music` autoload — renders songs on a background thread, picks one per scene folder (menu / race / everything else), crossfades |
| `autoload/audio_settings.gd` | `AudioSettings` autoload — per-bus volume + mute, saved to `user://settings.cfg` |
| `default_bus_layout.tres` | buses: Master, Music, SFX, Cars, Ambience, UI |
| `sounds/engines/<engine id>.tres` | one profile per engine part, looked up by id |
| `scripts/car/car_engine_audio.gd` | race car engine: rpm from wheel spin |
| `scripts/car/race_car_audio.gd` | `RaceCarAudio` — the mix rule for every race-car sound |

## Adding a one-shot or loop

1. Add the name to `SoundLibrary.NAMES` (and `LOOPING` if it loops).
2. Add a `match` arm in `SoundLibrary.render()` and write a `_builder(rng)` using `Synth`.
3. Play it:
   - `Sfx.play(&"name", volume_db, pitch_variation)` — non-positional (UI, pickups, the player's own car).
   - `Sfx.play_at(&"name", global_position, volume_db)` — world events other cars/props make.
   - `SustainedSound` child + `set_level()` every frame — ongoing things.

Building blocks by sound type:
- **Impacts / slams / clunks**: `Synth.thump()` (low-passed noise burst) + `_metal_ring()` for metal.
- **Beeps, horns, chimes, jingles**: `Synth.tones()`; square > 0 for buzzy/cheap.
- **Hiss, skids, wind, rain, steam**: `Synth.noise_sweep()`.
- **Motors and pistons**: `Synth.engine()` offline, or `EngineSound` live.

Loops must use `fade = 0` and start/end at the same level. Tones loop cleanly when the length holds a whole number of cycles of every frequency (the horn is 1.0 s at 330 + 415 Hz). Always seed noise from the `rng` passed in so sounds are identical every launch.

**Engines must stay subtle.** They're a bed under everything else, not the star. Keep them dark (`cutoff_max` ≲ 2200 Hz), with low drive (≲ 0.15), modest noise, and `rolloff` ≳ 1.3. User feedback on bright, loud engines was "a bee hive + a vacuum cleaner + a cargo ship at the same time". Never let several different engines play at full level at once.

**Race cars are all equal.** Every sound a race car makes (engine, bumps, crashes, stall, backfire) goes through `RaceCarAudio`: `RaceCarAudio.play(node, name, position, volume_db)` for one-shots, and `RaceCarAudio.mix_db()` on anything sustained. It scales each car by 1/√(number of cars), so no car (not even the player's) is louder than the others, and a full grid is about as loud as one car. New race-car sounds must use it, never `Sfx.play_at` directly.

Engine starts are an `ignition_click` one-shot followed by `EngineSound.start_up()`. The catch and rev blip come from the live engine voice, so the start always matches the fitted engine. Never bake a motor into a start one-shot.

Tone: junkyard, cheap, a little broken. Rattly, clunky, lo-fi, never glossy or orchestral. It should match the cut-out polygon look (see the `ui-style` skill).

## Buses

Every sound must land on a bus so the settings sliders cover it. `SoundLibrary.bus_for()` decides: names in `CAR_SOUNDS` → Cars, `UI_SOUNDS` → UI, `AMBIENT_SOUNDS` → Ambience, everything else → SFX. `Sfx`, `SustainedSound` and `EngineSound` apply it automatically, so a new sound only needs adding to the right list. Any new player created outside those must set `bus` itself.

## Music

Songs are silly junkyard funk: 16th-note syncopation, slap bass, clav stabs, ghost notes, chromatic runs and semitone chord slides, odd meters, stop-time breaks, cheesy key changes, wonky detune and tape wobble. User feedback on a tame folk version was "like a children youtube video" — keep it weird, never polite or epic. Add one in `SongLibrary` and map it in `Music._song_for_scene()`. Each renders in ~4–5 s on a background thread; keep songs under ~80 s. `MusicSynth` warns when a `|`-separated bar has the wrong step count.

## Adding an engine part

Create `sounds/engines/<part id>.tres` (an `EngineSoundProfile`). Without one the engine falls back to a plain petrol profile. Profiles are found by id, not stored on the part, because saves embed whole part resources.

Recipes from the existing profiles:
- Piston engine (`engine_v6`): buzz + sub + resonance.
- Steam (`engine_boiler`): low buzz, lots of noise, `chuff_level`.
- Turbine (`engine_jet`): little buzz, bright noise, `whine_level`.
- Small raspy motor (`engine_propeller`): low rolloff, high drive, a light `chuff` for the blade chop.
- No engine (`engine_sail`): `buzz_level = 0`. Noise through a low `resonance` gives the wind whoosh, `gust_level` makes it swell, a sharp jittery chuff (`chuff_sharpness` 12) gives the canvas snaps, and a faint high `whine` is the rigging whistle.

Keep rms at full rpm around 0.25–0.5 so engines are balanced. Measure by calling `EngineSound.synthesize()` in a headless script.

## Levels (dB, relative)

| Kind | Level |
|---|---|
| UI click | -8 |
| Pickups | -6 |
| Horn | -6 |
| Tyre screech | -12 |
| Door, sale, wrench, loot | -4 |
| Crash / break | -2 |
| Overworld car engine | -12 |
| Race engines | -14, then every race-car sound × 1/√(car count) |
| Rain | -8 × intensity |

## Performance

- One-shots are rendered once and cached. Rendering the whole library takes ~1 s in total, on a background thread. Keep new sounds short (< 2 s).
- A live `EngineSound` costs ~0.6 ms per frame, so a 6-car race spends ~4 ms on engines. If races grow, lower their cost (e.g. a lower mix rate for race engines) rather than silencing cars, because all cars must stay equal.
- Anything computed per sample in a live loop: inline filters into locals like `EngineSound.synthesize()` does.

## Current coverage (keep this updated)

Overworld car: engine (ignition click + live start once per session, live rpm), H horn, skid screech, wall bump, Shift backfire, door when entering a place. Race: live engines, impacts, part-break crash, body-break stall, finish-line backfire. Pickups: scrap blip, part arpeggio (also the crane haul). Trash looting rummage. Scrap dealer: cash register / denied. Crane: clang on grab, miss, denied. Garage: wrench clunk on fitting a part. All buttons click; ScrapButtons tick on hover. Rain ambience. Settings: each volume change previews through its bus. Music: menu (Junkyard Strut), overworld (Drunk Crane Shuffle, 7/8), races (Scrapheap Stampede).
