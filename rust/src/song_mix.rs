//! A song's mix bus. Lives natively so mixing a note doesn't copy the whole
//! song across the GDScript boundary on every hit.

use godot::prelude::*;
use std::f64::consts::TAU;

use crate::dsp::{SAMPLE_RATE, finish, lerp, softclip, to_packed, variant_f64};

/// RMS every song is brought down to.
const TARGET_LOUDNESS: f64 = 0.2;

#[derive(GodotClass)]
#[class(init, base = RefCounted)]
pub struct SongMix {
    samples: Vec<f32>,
}

#[godot_api]
impl SongMix {
    #[func]
    fn create(length: i64) -> Gd<Self> {
        Gd::from_object(SongMix { samples: vec![0.0; length.max(0) as usize] })
    }

    /// Add `note` from `offset`, wrapping past the end so tails ring into the
    /// start and the song loops seamlessly.
    #[func]
    fn mix_wrapped(&mut self, note: PackedFloat32Array, offset: i64, gain: f64) {
        let length = self.samples.len();
        if length == 0 {
            return;
        }
        for (i, &value) in note.as_slice().iter().enumerate() {
            let index = (offset as usize + i) % length;
            self.samples[index] = (self.samples[index] as f64 + value as f64 * gain) as f32;
        }
    }

    /// Master bus: tape edits, tape wobble, a little saturation, normalise, then
    /// cap the loudness so every song sits at the same level.
    #[func]
    fn master(&self, tape_edits: Array<VarDictionary>, wow_depth_ms: f64, wow_cycles: f64) -> PackedFloat32Array {
        let mut mixed = apply_tape_edits(self.samples.clone(), &tape_edits);
        mixed = apply_tape_wow(mixed, wow_depth_ms * 0.001 * SAMPLE_RATE, wow_cycles);
        for sample in &mut mixed {
            *sample = softclip(*sample as f64, 0.6) as f32;
        }
        finish(&mut mixed, 0.8, 0.0);
        let power: f64 = mixed.iter().map(|&s| s as f64 * s as f64).sum();
        let loudness = (power / mixed.len().max(1) as f64).sqrt();
        if loudness > TARGET_LOUDNESS {
            for sample in &mut mixed {
                *sample = (*sample as f64 * (TARGET_LOUDNESS / loudness)) as f32;
            }
        }
        to_packed(mixed)
    }
}

fn apply_tape_edits(mut mix: Vec<f32>, edits: &Array<VarDictionary>) -> Vec<f32> {
    let length = mix.len();
    if length == 0 {
        return mix;
    }
    for edit in edits.iter_shared() {
        let field = |key: &str| edit.get(key).map_or(0, |value| variant_f64(&value) as usize);
        let kind = edit.get("kind").map_or_else(GString::new, |value| value.to::<GString>()).to_string();
        let start = field("start");
        let source = mix.clone();
        let at = |offset: usize| source[(start + offset) % length] as f64;
        match kind.as_str() {
            "stutter" => {
                let slice = field("slice");
                for i in 0..slice * field("repeats") {
                    let within = i % slice;
                    mix[(start + i) % length] = (at(within) * edge_gain(within, slice)) as f32;
                }
            }
            "tape_stop" => {
                let span = field("length");
                let mut position = 0.0f64;
                for i in 0..span {
                    let speed = (1.0 - i as f64 / span as f64).powf(1.6);
                    let base = position.floor() as usize;
                    let sample = lerp(at(base), at(base + 1), position - base as f64);
                    mix[(start + i) % length] = (sample * edge_gain(i, span)) as f32;
                    position += speed;
                }
            }
            "reverse" => {
                let span = field("length");
                for i in 0..span {
                    mix[(start + i) % length] = (at(span - 1 - i) * edge_gain(i, span)) as f32;
                }
            }
            "dropout" => {
                let span = field("length");
                for i in 0..span {
                    mix[(start + i) % length] = (at(i) * (1.0 - edge_gain(i, span))) as f32;
                }
            }
            "crush" => {
                let span = field("length");
                let mut held = 0.0;
                for i in 0..span {
                    if i % 6 == 0 {
                        held = (at(i) * 6.0).round() / 6.0;
                    }
                    let gain = edge_gain(i, span);
                    mix[(start + i) % length] = (held * gain + at(i) * (1.0 - gain)) as f32;
                }
            }
            _ => {
                godot_error!("SongMix: unknown tape edit '{kind}'");
            }
        }
    }
    mix
}

/// Short fades at both ends of an edited stretch so the splices don't click.
fn edge_gain(index: usize, span: usize) -> f64 {
    const FADE: f64 = 60.0;
    (index as f64 / FADE).min((span as f64 - 1.0 - index as f64) / FADE).clamp(0.0, 1.0)
}

/// Variable delay read with a sine that fits whole cycles in the song, so the
/// wobble is seamless across the loop point.
fn apply_tape_wow(input: Vec<f32>, depth: f64, cycles: f64) -> Vec<f32> {
    if depth <= 0.0 {
        return input;
    }
    let length = input.len() as i64;
    (0..length)
        .map(|i| {
            let delay = depth * (1.0 + (TAU * cycles * i as f64 / length as f64).sin()) * 0.5;
            let position = i as f64 - delay;
            let base = position.floor() as i64;
            let fraction = position - base as f64;
            let sample = |index: i64| input[index.rem_euclid(length) as usize] as f64;
            lerp(sample(base), sample(base + 1), fraction) as f32
        })
        .collect()
}
