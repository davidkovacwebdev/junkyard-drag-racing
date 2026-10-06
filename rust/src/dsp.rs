//! Shared building blocks, mirroring the GDScript originals in synth.gd
//! operation for operation so renders stay identical.

use godot::prelude::*;
use std::f64::consts::{PI, TAU};

pub const SAMPLE_RATE: f64 = 22050.0;

pub fn sample_count(duration: f64) -> usize {
    (duration * SAMPLE_RATE).max(0.0) as usize
}

pub fn lerp(from: f64, to: f64, weight: f64) -> f64 {
    from + (to - from) * weight
}

/// Godot's `smoothstep`, including its handling of an empty range.
pub fn smoothstep(from: f64, to: f64, s: f64) -> f64 {
    if (from - to).abs() < 0.00001 {
        return if from <= to {
            if s <= from { 0.0 } else { 1.0 }
        } else if s <= to {
            1.0
        } else {
            0.0
        };
    }
    let x = ((s - from) / (to - from)).clamp(0.0, 1.0);
    x * x * (3.0 - 2.0 * x)
}

pub fn one_pole_coefficient(cutoff: f64) -> f64 {
    let w = TAU * cutoff / SAMPLE_RATE;
    w / (1.0 + w)
}

pub fn lowpass_noise_gain(cutoff: f64) -> f64 {
    let a = one_pole_coefficient(cutoff);
    1.0 / (a / (2.0 - a) / 3.0).sqrt()
}

pub fn softclip(x: f64, amount: f64) -> f64 {
    if amount <= 0.0 {
        return x;
    }
    (1.0 + amount) * x / (1.0 + amount * x.abs())
}

/// Two-pole state-variable filter coefficient, used by the plucky instruments.
pub fn state_variable_coefficient(cutoff: f64) -> f64 {
    2.0 * (PI * cutoff / SAMPLE_RATE).sin()
}

#[derive(Default)]
pub struct Formant {
    pub b0: f64,
    pub a1: f64,
    pub a2: f64,
    pub x1: f64,
    pub x2: f64,
    pub y1: f64,
    pub y2: f64,
}

impl Formant {
    pub fn tune(&mut self, frequency: f64, q: f64) {
        let w = TAU * frequency / SAMPLE_RATE;
        let alpha = w.sin() / (2.0 * q);
        let a0 = 1.0 + alpha;
        self.b0 = alpha / a0;
        self.a1 = -2.0 * w.cos() / a0;
        self.a2 = (1.0 - alpha) / a0;
    }

    pub fn tuned(frequency: f64, q: f64) -> Self {
        let mut formant = Formant::default();
        formant.tune(frequency, q);
        formant
    }

    pub fn step(&mut self, x: f64) -> f64 {
        let y = self.b0 * x - self.b0 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2;
        self.x2 = self.x1;
        self.x1 = x;
        self.y2 = self.y1;
        self.y1 = y;
        y
    }

    pub fn process(&mut self, x: f64, frequency: f64, q: f64) -> f64 {
        self.tune(frequency, q);
        self.step(x)
    }
}

pub struct LowPass {
    y: f64,
    a: f64,
}

impl LowPass {
    pub fn tuned(cutoff: f64) -> Self {
        LowPass { y: 0.0, a: one_pole_coefficient(cutoff) }
    }

    pub fn step(&mut self, x: f64) -> f64 {
        self.y += self.a * (x - self.y);
        self.y
    }

    pub fn process(&mut self, x: f64, cutoff: f64) -> f64 {
        self.a = one_pole_coefficient(cutoff);
        self.step(x)
    }
}

pub struct HighPass {
    low: LowPass,
}

impl HighPass {
    pub fn tuned(cutoff: f64) -> Self {
        HighPass { low: LowPass::tuned(cutoff) }
    }

    pub fn step(&mut self, x: f64) -> f64 {
        x - self.low.step(x)
    }
}

/// `[time_seconds, value]` pairs, linearly interpolated, holding the first/last
/// value outside the range.
pub struct Curve {
    points: Vec<(f64, f64)>,
}

impl Curve {
    pub fn from_array(points: &VarArray) -> Self {
        Curve {
            points: points
                .iter_shared()
                .map(|point| {
                    let pair = point.to::<VarArray>();
                    (variant_f64(&pair.at(0)), variant_f64(&pair.at(1)))
                })
                .collect(),
        }
    }

    pub fn sample(&self, t: f64) -> f64 {
        let first = self.points[0];
        if t <= first.0 {
            return first.1;
        }
        for pair in self.points.windows(2) {
            let (p0, p1) = (pair[0], pair[1]);
            if t <= p1.0 {
                return lerp(p0.1, p1.1, (t - p0.0) / (p1.0 - p0.0));
            }
        }
        self.points[self.points.len() - 1].1
    }
}

/// Peak-normalise and fade both ends (see `Synth.finish`).
pub fn finish(samples: &mut [f32], peak: f64, fade_time: f64) {
    let loudest = samples.iter().fold(0.0f64, |loudest, &s| loudest.max((s as f64).abs()));
    let gain = peak / if loudest > 0.0 { loudest } else { 1.0 };
    let n = samples.len();
    let fade = sample_count(fade_time);
    for i in 0..n {
        let mut v = samples[i] as f64 * gain;
        if fade > 0 {
            if i < fade {
                v *= i as f64 / fade as f64;
            }
            if i + fade >= n {
                v *= (n - 1 - i) as f64 / fade as f64;
            }
        }
        samples[i] = v as f32;
    }
}

/// Mix `other` into `samples` from `offset`, growing `samples` to fit.
pub fn mix_into(samples: &mut Vec<f32>, other: &[f32], offset: usize, gain: f64) {
    if samples.len() < offset + other.len() {
        samples.resize(offset + other.len(), 0.0);
    }
    for (i, &value) in other.iter().enumerate() {
        samples[offset + i] = (samples[offset + i] as f64 + value as f64 * gain) as f32;
    }
}

/// GDScript numbers arrive as either int or float variants.
pub fn variant_f64(value: &Variant) -> f64 {
    match value.get_type() {
        VariantType::INT => value.to::<i64>() as f64,
        _ => value.to::<f64>(),
    }
}

pub fn option_f64(options: &VarDictionary, key: &str, default: f64) -> f64 {
    options.get(key).map_or(default, |value| variant_f64(&value))
}

pub fn option_array(options: &VarDictionary, key: &str) -> VarArray {
    options.get(key).map_or_else(VarArray::new, |value| value.to::<VarArray>())
}

pub fn option_curve(options: &VarDictionary, key: &str) -> Curve {
    Curve::from_array(&option_array(options, key))
}

pub fn to_packed(samples: Vec<f32>) -> PackedFloat32Array {
    PackedFloat32Array::from(samples)
}
