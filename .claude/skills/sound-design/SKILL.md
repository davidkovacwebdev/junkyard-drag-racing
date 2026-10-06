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
| `scripts/audio/engine_sound.gd` | `EngineSound` — live engine synth (AudioStreamGenerator) driven by `rpm` and `throttle`; the samples come from the native `EngineVoice` |
| `rust/src/` | Native sample loops behind `Synth` (`synth_dsp.rs`), `EngineSound` (`engine_voice.rs`) and `MusicSynth`. They match the GDScript originals bit for bit; `tools/audio_parity_probe.gd` renders everything to raw files for before/after comparison |
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

Overworld car: engine (ignition click + live start once per session, live rpm), H horn, skid screech (also Space brake at speed, with skid marks), wall bump, Shift backfire, `headlight_click` when the lamps switch on at dusk / off at dawn (only on bodies with a `HeadlightMount`), door when entering a place. Race: live engines, impacts (soft parts like the mattress use their own `impact_sound`, e.g. `mattress_squish`, `sign_wobble` for the warning-sign wheel, also on the overworld wall bump), pogo stick `pogo_boing` on every takeoff (louder the deeper the squash), prosthetic leg `prosthetic_clunk` on every footstep (also its bump sound), long robot leg `robot_stomp` (servo whirr, steel clank, hydraulic hiss) on every footstep and bump (walking legs play their part's `impact_sound` per step), flat tyre `flat_tire_flop` bumps, giant wheel `giant_tire_boom` bumps, prop plane `fuselage_bong` bumps, T-rex fossil `bone_clatter` (dry thud + a clatter of hollow bone knocks) bumps, tank track `track_clank` (steel thunk + rattling links) bumps, upside-down car and half car scrape with `metal_scrape`, vertical car bumps with `collision`, V8 engine (`engine_v8`) has a deeper, lopier piston profile than the V6, radiator body `radiator_clang` and bicycle body `bicycle_rattle` as their bump sounds (the limo uses the plain car `bump`), tractor tire `tractor_thud` bumps, cardboard box body `cardboard_crumple` (papery bonk + dry crinkle) bumps, `rock_clack` when a wheel rolls onto a drag strip rock, `metal_scrape` when two drag racers touch, `spike_pop` (tinny clank, pop and air hiss) when a car drops onto the ramp jump's spike pit, `gravel_crunch` (thud + gravel spray, with a dust burst) when a rally car lands hard off a crest, puddle splash (reuses `paddle_splash`), hamster wheel `hamster_squeak` on bumps and when the hamster panics, CRT TV wheel `tv_thunk` bumps (sofa reuses `mattress_squish`, bicycle wheel reuses `bicycle_rattle`), part-break crash, body-break stall, finish-line backfire, `race_stalled` sad-trombone when nobody's moving (or a surrender) ends the race early, hill climb `summit_cowbell` (two dull clanks) when a car crosses the summit finish (RaceController.finish_sound), demolition derby `knockout_bell` (cheap boxing bell rung twice) when a car is knocked out, `results_fanfare` pluck when the podium screen shows (skipped on a STALLED or SURRENDER ending). Pickups: scrap blip, part arpeggio (also the crane haul). Trash looting rummage. Scrap dealer: cash register / denied. Farm horse seller: cash register + `horse_neigh` on a sale, denied when broke. Horse engine (`engine_horse`): hoof clip-clop profile (noise through a woody resonance, sharp `chuff`), and its `start_sound` / `boost_sound` (new `EnginePartData` fields, default `ignition_click` / `backfire`) are `horse_neigh`, so starting up and Shift-sprinting whinny instead of clicking and backfiring. Desert hangar: the hidden flying saucer hums with a positional `ufo_hum_loop` (Ambience bus), driving in while it's still there plays the `ufo_reveal` theremin sting, taking it starts the alien escape cutscene: the dome pops with `ufo_hatch`, the alien pilot Zib (tuned squeaky CharacterVoice) squeals `alien_yelp` as he jumps out and again as he bolts, then `part_pickup` + `ufo_warble` as the empty saucer is yours; the saucer body (`body_ufo`) bumps with `ufo_warble`. The sea: driving off the sand into the water plays a `car_splash`, sinking to the axles a `car_sink_glug`; Hank's tow truck then backs in with `tow_reverse_beep` over a quiet positional engine hum, a `door_close` as he climbs out and back in, the `tow_winch` whine + ratchet (with another `car_splash`) as the car is hauled out, `cash_register` when he takes the $20 fee, and a `truck_honk` as he drives off; Hank talks in his tuned CharacterVoice. From the third tow Hank hands over his fishing rod (`part_pickup` with the title card). Fishing rod (trunk item, reusable, needs water nearby or it's `denied`): `rod_cast` swish + line zip on the cast, `bobber_plop` (positional) when it lands and twice on a bite, `reel_whirr` ratchet reeling in, then the catch arcs into the car as a scrap or part orb with its usual pickup sound, or a `boot_squelch` for an old boot. Sharks: `shark_splash` (Ambience bus) when one surfaces or dives in the overworld ocean. Wildlife: beach gulls and graveyard crows take off with a positional `wing_flutter` (Ambience bus) when the car gets close, plus their `gull_cry` / `crow_caw` most of the time; driving through a desert tumbleweed plays `tumbleweed_crunch`; the yard dog by the garage barks `dog_bark` (positional, SFX bus) all the while it chases the car; farm chickens scatter with a `chicken_cluck` "bok bok bok" (Ambience bus, not every time) and squawk a loud `chicken_squawk` (SFX bus) when the car clips them; the roaming fishing boat carries a positional `boat_putter_loop` motor (Ambience bus, a `SustainedSound` that fades out while it stops to fish). Scrap forge: `crucible_drop` when a part goes into (or comes out of) a crucible, three `forge_hammer` clangs while the mash is hammered, `forge_quench` hiss when the new part comes out, denied when broke / too few parts / crucibles full, and a positional `furnace_loop` roar (Ambience bus) around the smelter. Scenery landmarks (Ambience bus, positional, via `AmbientCall` which repeats a one-shot at random intervals): fishing port `gull_cry`, lighthouse `foghorn` + gulls, graveyard `crow_caw` (also inside the cemetery), crop fields `cricket_chirp`, shipwreck `hull_creak` (woody groan + loose-timber knocks) + gulls, offshore oil rig `rig_clank` (steel clank with a long ring), crashed helicopter `rotor_creak` (rusty groan as the bent blade swings), satellite array hut `dish_chirp` (buzzy telemetry blips), lonely island castaway `castaway_holler` ("hey-oooo!"); the town water tower plays `tank_drip` each time a drop from its leaky tank hits the ground; each oil pumpjack plays `pumpjack_creak` once per stroke as its head bottoms out. Graveyard gate: `gate_rattle` while it's chained shut, `cemetery_gate_creak` (rusty hinge creak + clank) as it swings open to drive into the cemetery. Drag Queen's grave: Grandpa's wheel set down with a `wood_clonk`, then a `funeral_bell` toll for the moment of silence. Race booths that haven't opened yet (the Hill Climb until "King of the Hill") play `denied` on E. Garbage truck: quiet constant-rpm ambient engine hum, `crane_clang` when it empties a bin it drives past (from noon on), `truck_honk` when rammed hard or shoved well off its route (3 s cooldown). Crane: quiet `cash_register` as each dig is paid for, `crane_shove` thud (rate-limited) when the physical claw shells bump junk or the floor, clang on grab, miss, denied. Junkyard: `gate_rattle` (chain-link shiver + post clank) when the car drives out the front gate. Garage: wrench clunk on fitting a part; an accessory plays its own `equip_sound` instead (`gps_bloop`, `axe_whoosh`, `shell_knock`, `siren_whoop`, `balloon_squeak`, `glove_boing`, `can_clatter`, `windup_ratchet`, `tape_rip`, `bubble_pop`, anchor `crane_clang`, rocket `backfire`). Car accessories (only when fitted to the map car or a race rig, never in previews; race ones through `RaceCarAudio`): GPS arrow `gps_bloop` "recalculating" when you drive away from the quest target, axe `axe_whoosh` on every chop and `axe_chop` when a race chop lands on another car, boxing glove `glove_boing` on every punch and `glove_punch` when a race punch lands, tin cans `can_rattle_loop` following speed, the dragged anchor grinds with `anchor_drag_loop` following speed, siren light turns the horn into `siren_loop`, turtle shell knocks with `shell_knock` and bubble wrap with `bubble_pop` (race and map bumps). Character dialogs (`CharacterDialog`): `dialog_open` board slap on open (lower pitch on close), gibberish speech while the line types: `CharacterVoice` (`scripts/audio/character_voice.gd`) renders formant-filtered vowel syllables (a/e/i/o/u) that follow the vowels in the text, shaped by each `CharacterData`'s Voice group (`voice_pitch_hz`, `voice_throat`, `voice_rasp`, `voice_wobble`); an untuned character gets a voice derived from its name. Every new character should get its voice tuned. Cutscenes: `cutscene_whoosh` as the letterbox bars slide in (higher pitch as they slide out). Grandpa (`GrandpaNpc`, parked by the starter car): a quiet positional `beer_sip` slurp every few seconds as he leans back for a drink, `grandpa_twitch` stuttering buzz when he has a fit (opening cutscene), `wrench_clunk` when he whacks his busted wheelchair in the wrench scene; in the crane scene `grandpa_sob` (wet sniff + quavering wails, with falling tears), `grandpa_hiccup` drunk hic and a `wink_ting` when he winks; handing in "Gone Fishin'" empty-handed sets him bawling (two louder `grandpa_sob`s with a `grandpa_hiccup` between); in the first-race scene he tears up silently, then bawls out loud (a loud `grandpa_sob` with a camera rattle) after handing over the entry fee (`cash_register` via `start_money`); in the race-result scene a `beer_sip` if you lost, a `grandpa_hiccup` if you won; back from the ramp beaten up, he rocks in his chair with a `grandpa_laugh` belly laugh, rolls his wheelchair over to the car with a `wheelchair_squeak` and whacks it with the new wrench (`wrench_clunk` + a hollow `car_whack` off the panel); the second time he wheezes through a louder `grandpa_cackle` with tears, then a `grandpa_laugh`, and hands over $40 (`cash_register`); handing in the Beer Run six-pack cracks a can (`beer_crack`, the quest's `turn_in_sound`); on the Drag Queen's anniversary he sobs (`grandpa_sob`), shakes with rage (`grandpa_twitch` + a camera rattle), the player smooches the little trans flag on his wheelchair with a `flag_kiss` (and a heart), and his nail-studded wooden steering wheel pops up with a `wood_clonk`; reporting back, his eyes pop wide with a `grandpa_gasp` (sharp raspy "HUH!") when he asks about drag racers, and he twitches with annoyance (`grandpa_twitch`) at the questions; in the chains scene his eyes pop (`grandpa_gasp`) at the mention of chains; handing them in opens on his bacon smoker sizzling (`bacon_sizzle`), he coughs on the smoke (`grandpa_hiccup`) and the chains go up on the smoker's bar with a `chain_rattle`; from then on the smoker by his garage sizzles now and then (positional `bacon_sizzle` via `AmbientCall`, Ambience bus); his voice is tuned low, raspy and quavery. Trunk (I): `trunk_open` latch clack + hinge groan + bounce, `trunk_close` slam; using an item (1-6 or double-click) plays its `ItemData.use_sound` (the six-pack: `beer_chug`, can crack + three gulps + "ahh"), `denied` for items that can't be used. Drunk on the map (5+ beers): the car pulls over to `puke` (two dry heaves, a gurgling hurl and splatter, timed to the puddle landing). Shop: `shop_bell` door dings on walking in, `cash_register` on a purchase, `denied` when broke or the trunk is full; a `ui_hover` tick when More Stuff, the mouse wheel or the arrow keys scroll the item list; the shopkeeper talks in his tuned CharacterVoice. Quests: `quest_added` (pencil scratch + toy-keyboard ding-dong) with the NEW QUEST card, `quest_added` again with the OBJECTIVE DONE card (go back to the giver), `quest_complete` three-note climb plus `cash_register` when the giver pays the reward, `cash_register` too when a quest comes with `start_money` (Grandpa's $100 for the crane); journal (J) `journal_flip` paper riffle on open, lower on close; the full map (M) uses the same riffle, and `denied` when you don't own the Map. World camera: `binocular_focus` (three plastic focus-ring ticks) when zooming out past the default zoom with binoculars. Race camera: quiet `binocular_focus` when Tab switches which car it rides with and when R resets it. Race office (venue menu): the race clerk talks in his tuned CharacterVoice on every page, on a bet result and when you can't pay. Character creation (New Game): `outfit_swap` cloth flap on every part change and on Randomize, `denied` when starting with no name, `door_close` on Hit the Road. Loading board (`SceneLoader`): `loading_crank` (three ratchet clicks and a rubbery tyre bwomp) as it pops up. Save slots screen: `denied` when Delete is armed ("Sure?"), `profile_scrapped` (crumple + tin can clattering into a bin) when a slot is deleted. All buttons click; ScrapButtons tick on hover. Rain ambience. Ctrl+K skip-to-morning `rooster_crow`. Settings: each volume change previews through its bus. Music playlists: menu (Glup Glup Dupy Doo, Junkyard Strut), overworld (Goblin Gumbo Wobble 5/4, Drunk Crane Shuffle 7/8), races (Blorp Hup Hup Stampede, Scrapheap Stampede).
