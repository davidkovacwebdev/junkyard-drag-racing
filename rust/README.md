# junk_native (Rust GDExtension)

The game's hot loops run in a Rust GDExtension (`junk_native`), built with [godot-rust](https://godot-rust.github.io/) (`godot` crate 0.5, API 4.7):

| File | Class | Used by |
|---|---|---|
| `src/synth_dsp.rs` | `SynthDsp` | `Synth` (all SFX) |
| `src/engine_voice.rs` | `EngineVoice` | `EngineSound` (live car engines) |
| `src/music_dsp.rs`, `src/song_mix.rs` | `MusicDsp`, `SongMix` | `MusicSynth` (song baking) |
| `src/road_geometry.rs` | `RoadGeometry`, `SegmentGrid` | `RoadNetwork` (`scripts/world/road.gd`) |

The GDScript side keeps its API. Only the per-sample and per-point loops moved, and their output matches the old GDScript bit for bit.

**The project does not run without the compiled library.** The built files are not in git (`rust/target/` is ignored). Without them Godot fails to load `junk_native.gdextension`, and every script that uses these classes fails to parse.

## Setup (once)

1. Install Rust: <https://rustup.rs> (`rustup` installs `cargo`).
2. Build the debug library, which is the one the editor loads:
   ```
   cd rust
   cargo build
   ```
3. Open the project in Godot 4.7. It picks up `junk_native.gdextension` from the project root.

The first build downloads and compiles godot-rust, which takes a few minutes. Later builds take seconds.

## After pulling or editing Rust code

Run `cargo build` in `rust/` again, then restart the editor (or reopen the project). Godot can't swap a library it has already loaded.

## Build targets

`junk_native.gdextension` maps each platform to a file under `rust/target/`:

| Godot build | Library |
|---|---|
| Editor and debug exports | `rust/target/debug/` (`cargo build`) |
| Release exports | `rust/target/release/` (`cargo build --release`) |

The debug profile is optimised (`opt-level = 3` in `Cargo.toml`), so the editor isn't slow.

- **Linux:** `libjunk_native.so`.
- **Windows:** `junk_native.dll`. Build on Windows with the same commands (MSVC Rust is fine). Cross-compiling from Linux needs `rustup target add x86_64-pc-windows-gnu`, mingw-w64 (`x86_64-w64-mingw32-gcc`), and `cargo build --release --target x86_64-pc-windows-gnu`. In that case copy the `.dll` to `rust/target/release/`, or point the `windows.*` lines of the `.gdextension` at `rust/target/x86_64-pc-windows-gnu/release/`.
- **macOS:** `libjunk_native.dylib`, built on a Mac.

**Before exporting, build the release library for the export's platform.** The "Windows Desktop" preset needs `junk_native.dll`, or the exported game won't start.

## Checking a change still matches

- **Audio:** `godot --headless --script res://tools/audio_parity_probe.gd -- <out_dir> --no-save` renders every SFX, song and a few engine runs to raw files, plus timings. Run it before and after a change and compare the files.
- **Roads:** dump `RoadNetwork`'s derived arrays before and after a change in the same way.
