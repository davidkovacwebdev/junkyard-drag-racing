# Merge notes: Rust native code and the loading screen

**You now need Rust to run the project.** Audio DSP and road geometry moved into a Rust GDExtension (`junk_native`, in `rust/`). The compiled library isn't in git, so after pulling:

1. Install Rust from <https://rustup.rs>.
2. Run `cargo build` in `rust/`.
3. Restart the Godot editor.

Rebuild after pulling any change under `rust/`. Exports need `cargo build --release` for the export platform, so the Windows preset needs `junk_native.dll`. All the details are in `rust/README.md`.

- **Audio:** `Synth`, `MusicSynth` and `EngineSound` keep their GDScript API, but their sample loops now live in Rust. Renders are bit-identical to before, about 16× faster for SFX and songs and 8× for live engines.
- **Roads:** `RoadNetwork` (`road.gd`) keeps its API; its geometry now lives in Rust. Output is identical, and the first world load dropped from about 0.74 s to 0.34 s.
- **Loading screen:** use `SceneLoader.change_scene(path)` / `change_scene_packed(packed)` instead of `get_tree().change_scene_to_*()` for anything entering or leaving gameplay. It shows a loading board while the scene loads in the background. Only instant hops between `scenes/menu/` screens call `change_scene_to_file()` directly.

# Merge notes: drag race scene swap

The old E-key race scene was removed. If your branch still points at it, move that code over to the new scene.

- **Deleted:** `scenes/race/race_random_test.tscn`. This was the wrong race scene, the one E used to open.
- **Renamed:** `scenes/race/race_test_lane.tscn` is now `scenes/race/race_drag_strip.tscn`. This is the old T-key scene with lane steering and collisions. Its root node was renamed from `RaceTestLane` to `RaceDragStrip`.
- **E key:** `scenes/world/drag_strip.tscn` now opens `race_drag_strip.tscn` on E. It no longer sets `test_interior_scene`, so T does nothing at the drag strip.
- **Race script:** `scripts/race/single_lane_race_setup.gd`. It spawns the player and the rivals (from `RaceProgression.pick_rivals`) and records wins.
- **End-of-race hook:** `RaceController` now emits `race_ended(winner_name: String)` before it leaves the scene. `winner_name` is empty if nobody finished. The player's car is registered as `"Player_<display name>"`.
- **Result screen:** attach it to `race_drag_strip.tscn`, not `race_random_test.tscn`. `RaceController.end_delay` may need to be above 0 so the screen has time to show before the scene exits.
- `scripts/race/random_race_setup.gd` is unchanged. Only the ramp test (`race_ramp_test.tscn`) still uses it.
