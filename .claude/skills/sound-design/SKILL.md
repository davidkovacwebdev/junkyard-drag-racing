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
| `scripts/audio/music_synth.gd` | `MusicSynth` — music sequencer, instruments, singers, tape edits (see the `music` skill) |
| `scripts/audio/songs/*.gd` | One recipe file per song |
| `scripts/audio/song_library.gd` | `SongLibrary` — song registry and per-scene playlists |
| `autoload/music.gd` | `Music` autoload — plays the playlist for the scene folder (menu / race / everything else), crossfades between songs |
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

Everything about songs (composing, style, versioning, rendering, playlists) is in the `music` skill. Never delete or overwrite a song.

## Adding an engine part

Create `sounds/engines/<part id>.tres` (an `EngineSoundProfile`). Without one the engine falls back to a plain petrol profile. Profiles are found by id, not stored on the part, because saves embed whole part resources.

Recipes from the existing profiles:
- Piston engine (`engine_v6`): buzz + sub + resonance.
- Steam (`engine_boiler`): low buzz, lots of noise, `chuff_level`.
- Turbine (`engine_jet`): little buzz, bright noise, `whine_level`.
- Small raspy motor (`engine_propeller`): low rolloff, high drive, a light `chuff` for the blade chop.
- Hooves (`engine_horse`): `buzz_level = 0`, noise through a ~520 Hz resonance, `chuff_level` ≈ 1 with sharpness ~14 so the level is all clops; idle nearly silent.
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

Overworld car: engine (ignition click + live start once per session, live rpm), H horn, skid screech (also Space brake at speed, with skid marks), wall bump, Shift backfire, `headlight_click` when the lamps switch on at dusk / off at dawn (only on bodies with a `HeadlightMount`), door when entering a place. Race: live engines, impacts (soft parts like the mattress use their own `impact_sound`, e.g. `mattress_squish`, `sign_wobble` for the warning-sign wheel, also on the overworld wall bump), pogo stick `pogo_boing` on every takeoff (louder the deeper the squash), prosthetic leg `prosthetic_clunk` on every footstep (also its bump sound), radiator body `radiator_clang` and bicycle body `bicycle_rattle` as their bump sounds (the limo uses the plain car `bump`), tractor tire `tractor_thud` bumps, `rock_clack` when a wheel rolls onto a drag strip rock, `metal_scrape` when two drag racers touch, puddle splash (reuses `paddle_splash`), hamster wheel `hamster_squeak` on bumps and when the hamster panics, CRT TV wheel `tv_thunk` bumps (sofa reuses `mattress_squish`, bicycle wheel reuses `bicycle_rattle`), part-break crash, body-break stall, finish-line backfire, `race_stalled` sad-trombone when nobody's moving (or a surrender) ends the race early, `results_fanfare` pluck when the podium screen shows (skipped on a STALLED or SURRENDER ending). Pickups: scrap blip, part arpeggio (also the crane haul). Trash looting rummage. Scrap dealer: cash register / denied. Farm horse seller: cash register + `horse_neigh` on a sale, denied when broke. Horse engine (`engine_horse`): hoof clip-clop profile (noise through a woody resonance, sharp `chuff`), and its `start_sound` / `boost_sound` (new `EnginePartData` fields, default `ignition_click` / `backfire`) are `horse_neigh`, so starting up and Shift-sprinting whinny instead of clicking and backfiring. Sharks: `shark_splash` (Ambience bus) when one surfaces or dives in the overworld ocean. Scrap forge: `crucible_drop` when a part goes into (or comes out of) a crucible, three `forge_hammer` clangs while the mash is hammered, `forge_quench` hiss when the new part comes out, denied when broke / too few parts / crucibles full, and a positional `furnace_loop` roar (Ambience bus) around the smelter. Garbage truck: quiet constant-rpm ambient engine hum, `crane_clang` when it empties a bin it drives past (from noon on), `truck_honk` when rammed hard or shoved well off its route (3 s cooldown). Crane: quiet `cash_register` as each dig is paid for, `crane_shove` thud (rate-limited) when the physical claw shells bump junk or the floor, clang on grab, miss, denied. Garage: wrench clunk on fitting a part. Character dialogs (`CharacterDialog`): `dialog_open` board slap on open (lower pitch on close), gibberish speech while the line types: `CharacterVoice` (`scripts/audio/character_voice.gd`) renders formant-filtered vowel syllables (a/e/i/o/u) that follow the vowels in the text, shaped by each `CharacterData`'s Voice group (`voice_pitch_hz`, `voice_throat`, `voice_rasp`, `voice_wobble`); an untuned character gets a voice derived from its name. Every new character should get its voice tuned. Cutscenes: `cutscene_whoosh` as the letterbox bars slide in (higher pitch as they slide out). Character creation (New Game): `outfit_swap` cloth flap on every part change and on Randomize, `denied` when starting with no name, `door_close` on Hit the Road. All buttons click; ScrapButtons tick on hover. Rain ambience. Ctrl+K skip-to-morning `rooster_crow`. Settings: each volume change previews through its bus. Music playlists: menu (Glup Glup Dupy Doo, Junkyard Strut), overworld (Goblin Gumbo Wobble 5/4, Drunk Crane Shuffle 7/8), races (Blorp Hup Hup Stampede, Scrapheap Stampede).
