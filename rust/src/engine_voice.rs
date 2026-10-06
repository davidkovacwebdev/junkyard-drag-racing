//! The live engine voice behind `EngineSound`: one per running car, asked for a
//! chunk of samples every frame.

use godot::classes::Resource;
use godot::prelude::*;
use std::f64::consts::TAU;

use crate::dsp::{Formant, SAMPLE_RATE, lerp, lowpass_noise_gain, one_pole_coefficient, variant_f64};
use crate::pcg::Pcg;

const WAVETABLE_SIZE: usize = 2048;

/// The EngineSoundProfile fields, read once in `configure()`.
#[derive(Default)]
struct Profile {
    idle_frequency: f64,
    max_frequency: f64,
    jitter: f64,
    jitter_rate: f64,
    knock: f64,
    knock_rate: f64,
    buzz_level: f64,
    harmonics: i64,
    rolloff: f64,
    sub_level: f64,
    drive: f64,
    noise_level: f64,
    noise_cutoff: f64,
    cutoff_idle: f64,
    cutoff_max: f64,
    resonance_frequency: f64,
    resonance_q: f64,
    resonance_gain: f64,
    whine_level: f64,
    whine_ratio: f64,
    chuff_level: f64,
    chuff_ratio: f64,
    chuff_sharpness: f64,
    gust_level: f64,
    gust_rate: f64,
    idle_volume: f64,
    max_volume: f64,
    throttle_boost: f64,
}

impl Profile {
    fn read(resource: &Gd<Resource>) -> Self {
        let field = |name: &str| variant_f64(&resource.get(name));
        Profile {
            idle_frequency: field("idle_frequency"),
            max_frequency: field("max_frequency"),
            jitter: field("jitter"),
            jitter_rate: field("jitter_rate"),
            knock: field("knock"),
            knock_rate: field("knock_rate"),
            buzz_level: field("buzz_level"),
            harmonics: field("harmonics") as i64,
            rolloff: field("rolloff"),
            sub_level: field("sub_level"),
            drive: field("drive"),
            noise_level: field("noise_level"),
            noise_cutoff: field("noise_cutoff"),
            cutoff_idle: field("cutoff_idle"),
            cutoff_max: field("cutoff_max"),
            resonance_frequency: field("resonance_frequency"),
            resonance_q: field("resonance_q"),
            resonance_gain: field("resonance_gain"),
            whine_level: field("whine_level"),
            whine_ratio: field("whine_ratio"),
            chuff_level: field("chuff_level"),
            chuff_ratio: field("chuff_ratio"),
            chuff_sharpness: field("chuff_sharpness"),
            gust_level: field("gust_level"),
            gust_rate: field("gust_rate"),
            idle_volume: field("idle_volume"),
            max_volume: field("max_volume"),
            throttle_boost: field("throttle_boost"),
        }
    }
}

#[derive(GodotClass)]
#[class(init, base = RefCounted)]
pub struct EngineVoice {
    profile: Profile,
    wavetable: Vec<f32>,
    rng: Option<Pcg>,
    body: Formant,
    jitter_gain: f64,
    knock_gain: f64,
    gust_gain: f64,
    phase: f64,
    sub_phase: f64,
    whine_phase: f64,
    chuff_phase: f64,
    last_frequency: f64,
    last_amplitude: f64,
    lowpass_y: f64,
    noise_y: f64,
    jitter_y: f64,
    knock_y: f64,
    gust_y: f64,
}

#[godot_api]
impl EngineVoice {
    /// Load an EngineSoundProfile. `seed` picks the noise sequence.
    #[func]
    fn configure(&mut self, profile: Gd<Resource>, seed: i64) {
        self.profile = Profile::read(&profile);
        let profile = &self.profile;
        self.wavetable = wavetable(profile);
        self.rng = Some(Pcg::from_seed(seed as u64));
        self.jitter_gain = lowpass_noise_gain(profile.jitter_rate);
        self.knock_gain = lowpass_noise_gain(profile.knock_rate);
        self.gust_gain = lowpass_noise_gain(profile.gust_rate);
        if profile.resonance_frequency > 0.0 {
            self.body.tune(profile.resonance_frequency, profile.resonance_q);
        }
        self.last_frequency = profile.idle_frequency;
    }

    /// The next `frames` stereo samples at `rpm` (0 idle .. 1.2) and `throttle`
    /// (0..1), faded by `master_level`. Pitch and level ramp across the chunk
    /// from the previous call's values instead of stepping, which would zipper.
    #[func]
    fn synthesize(&mut self, frames: i64, rpm: f64, throttle: f64, master_level: f64) -> PackedVector2Array {
        let frames = frames.max(0) as usize;
        let profile = &self.profile;
        let Some(rng) = self.rng.as_mut() else {
            godot_error!("EngineVoice: synthesize() before configure()");
            return PackedVector2Array::new();
        };
        let load_amount = throttle * profile.throttle_boost;
        let frequency = lerp(profile.idle_frequency, profile.max_frequency, rpm);
        let amplitude = lerp(profile.idle_volume, profile.max_volume, rpm) * (1.0 + load_amount) * master_level;
        let cutoff = lerp(profile.cutoff_idle, profile.cutoff_max, (rpm + load_amount).clamp(0.0, 1.2));

        let lowpass_a = one_pole_coefficient(cutoff);
        let noise_a = one_pole_coefficient(profile.noise_cutoff);
        let jitter_a = one_pole_coefficient(profile.jitter_rate);
        let knock_a = one_pole_coefficient(profile.knock_rate);
        let gust_a = one_pole_coefficient(profile.gust_rate);
        let jitter_depth = profile.jitter * self.jitter_gain;
        let knock_depth = profile.knock * self.knock_gain;
        let gust_depth = profile.gust_level * self.gust_gain;
        let noise_level = profile.noise_level * 3.0;
        let drive = profile.drive * 4.0;
        let has_resonance = profile.resonance_frequency > 0.0;
        let inverse_rate = 1.0 / SAMPLE_RATE;
        let table = &self.wavetable;
        let table_size = WAVETABLE_SIZE as f64;
        let table_mask = WAVETABLE_SIZE - 1;
        let body = &mut self.body;

        let mut buffer = Vec::with_capacity(frames);
        for i in 0..frames {
            let k = (i + 1) as f64 / frames as f64;
            let noise = rng.randf() * 2.0 - 1.0;
            self.jitter_y += jitter_a * (noise - self.jitter_y);
            self.knock_y += knock_a * (noise - self.knock_y);
            let mut f = lerp(self.last_frequency, frequency, k) * (1.0 + jitter_depth * self.jitter_y + knock_depth * self.knock_y);
            f = f.max(0.5);

            self.phase += f * inverse_rate;
            if self.phase >= 1.0 {
                self.phase -= 1.0;
            }
            let table_position = self.phase * table_size;
            let index = table_position as usize;
            let fraction = table_position - index as f64;
            let a = table[index] as f64;
            let mut source = (a + (table[(index + 1) & table_mask] as f64 - a) * fraction) * profile.buzz_level;
            if profile.sub_level > 0.0 {
                self.sub_phase += f * 0.5 * inverse_rate;
                if self.sub_phase >= 1.0 {
                    self.sub_phase -= 1.0;
                }
                source += profile.sub_level * (TAU * self.sub_phase).sin();
            }
            if noise_level > 0.0 {
                self.noise_y += noise_a * (noise - self.noise_y);
                source += self.noise_y * noise_level;
            }
            if drive > 0.0 {
                source = (1.0 + drive) * source / (1.0 + drive * source.abs());
            }
            self.lowpass_y += lowpass_a * (source - self.lowpass_y);
            source = self.lowpass_y;
            if has_resonance {
                let resonant = body.b0 * (source - body.x2) - body.a1 * body.y1 - body.a2 * body.y2;
                body.x2 = body.x1;
                body.x1 = source;
                body.y2 = body.y1;
                body.y1 = resonant;
                source += resonant * profile.resonance_gain;
            }
            if profile.whine_level > 0.0 {
                self.whine_phase += f * profile.whine_ratio * inverse_rate;
                self.whine_phase -= self.whine_phase.floor();
                source += (TAU * self.whine_phase).sin() * profile.whine_level;
            }

            let mut level = lerp(self.last_amplitude, amplitude, k);
            if profile.chuff_level > 0.0 {
                self.chuff_phase += f * profile.chuff_ratio * inverse_rate;
                self.chuff_phase -= self.chuff_phase.floor();
                let pulse = (0.5 + 0.5 * (TAU * self.chuff_phase).sin()).powf(profile.chuff_sharpness);
                level *= 1.0 - profile.chuff_level + profile.chuff_level * pulse;
            }
            if gust_depth > 0.0 {
                self.gust_y += gust_a * (noise - self.gust_y);
                level *= (1.0 + gust_depth * self.gust_y).clamp(0.15, 2.0);
            }
            let sample = ((source * level).tanh() * 0.8) as f32;
            buffer.push(Vector2::new(sample, sample));
        }
        self.last_frequency = frequency;
        self.last_amplitude = amplitude;
        PackedVector2Array::from(buffer)
    }
}

/// One normalised cycle of the band-limited buzz. Harmonics are capped so the
/// top one stays under Nyquist even at the profile's max firing frequency.
fn wavetable(profile: &Profile) -> Vec<f32> {
    let harmonics = profile
        .harmonics
        .min(((SAMPLE_RATE / 2.0 - 200.0) / (profile.max_frequency * 1.2)) as i64)
        .max(1);
    let mut loudest = 0.0f64;
    let mut table: Vec<f32> = (0..WAVETABLE_SIZE)
        .map(|i| {
            let phase = i as f64 / WAVETABLE_SIZE as f64;
            let mut sum = 0.0;
            for h in 1..=harmonics {
                sum += (TAU * h as f64 * phase).sin() / (h as f64).powf(profile.rolloff);
            }
            loudest = loudest.max(sum.abs());
            sum as f32
        })
        .collect();
    for value in &mut table {
        *value = (*value as f64 / loudest) as f32;
    }
    table
}
