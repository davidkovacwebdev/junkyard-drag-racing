//! Native code for the game's hot loops: synthesized audio (Synth, MusicSynth,
//! EngineSound) and road geometry (RoadNetwork). GDScript keeps the recipes,
//! sequencing and scene logic; the per-sample and per-point loops live here.

use godot::prelude::*;

mod dsp;
mod engine_voice;
mod music_dsp;
mod pcg;
mod road_geometry;
mod song_mix;
mod synth_dsp;

struct JunkNative;

#[gdextension]
unsafe impl ExtensionLibrary for JunkNative {}
