//! The sample loops behind `Synth`. GDScript's Synth keeps the documented API
//! and forwards here.

use godot::classes::RandomNumberGenerator;
use godot::prelude::*;
use std::f64::consts::TAU;

use crate::dsp::{
    Curve, Formant, HighPass, LowPass, SAMPLE_RATE, finish, lowpass_noise_gain, mix_into,
    option_array, option_curve, option_f64, sample_count, softclip, to_packed, variant_f64,
};
use crate::pcg::with_rng;

#[derive(GodotClass)]
#[class(no_init)]
pub struct SynthDsp;

#[godot_api]
impl SynthDsp {
    #[func]
    fn engine(duration: f64, options: VarDictionary, mut rng: Gd<RandomNumberGenerator>) -> PackedFloat32Array {
        let harmonics = option_f64(&options, "harmonics", 20.0) as i64;
        let rolloff = option_f64(&options, "rolloff", 1.2);
        let sub = option_f64(&options, "sub", 0.0);
        let noise_level = option_f64(&options, "noise", 0.0);
        let noise_cutoff = option_f64(&options, "noise_cutoff", 2000.0);
        let jitter = option_f64(&options, "jitter", 0.0);
        let jitter_rate = option_f64(&options, "jitter_rate", 80.0);
        let knock = option_f64(&options, "knock", 0.0);
        let knock_rate = option_f64(&options, "knock_rate", 18.0);
        let drive = option_f64(&options, "drive", 0.0);
        let resonance: Vec<f64> = option_array(&options, "resonance").iter_shared().map(|v| variant_f64(&v)).collect();
        let frequency_curve = option_curve(&options, "freq");
        let cutoff_curve = option_curve(&options, "cutoff");
        let amp_curve = option_curve(&options, "amp");

        let mut lowpass = LowPass::tuned(1.0);
        let mut body = Formant::default();
        if !resonance.is_empty() {
            body.tune(resonance[0], resonance[1]);
        }
        let mut noise_filter = LowPass::tuned(noise_cutoff);
        let mut jitter_filter = LowPass::tuned(jitter_rate);
        let mut knock_filter = LowPass::tuned(knock_rate);
        let jitter_gain = lowpass_noise_gain(jitter_rate);
        let knock_gain = lowpass_noise_gain(knock_rate);

        let mut out = vec![0.0f32; sample_count(duration)];
        with_rng(&mut rng, |rng| {
            let mut phase = 0.0;
            let mut sub_phase = 0.0;
            for (i, sample) in out.iter_mut().enumerate() {
                let t = i as f64 / SAMPLE_RATE;
                let mut frequency = frequency_curve.sample(t);
                if jitter > 0.0 {
                    frequency *= 1.0 + jitter * jitter_filter.step(rng.noise()) * jitter_gain;
                }
                if knock > 0.0 {
                    frequency *= 1.0 + knock * knock_filter.step(rng.noise()) * knock_gain;
                }
                frequency = frequency.max(8.0);
                phase += frequency / SAMPLE_RATE;
                let mut source = buzz(phase, frequency, harmonics, rolloff);
                if sub > 0.0 {
                    sub_phase += frequency * 0.5 / SAMPLE_RATE;
                    source += sub * (TAU * sub_phase).sin();
                }
                if noise_level > 0.0 {
                    source += noise_filter.step(rng.noise()) * noise_level;
                }
                source = softclip(source, drive * 4.0);
                source = lowpass.process(source, cutoff_curve.sample(t));
                if !resonance.is_empty() {
                    source += body.step(source) * resonance[2];
                }
                *sample = (source * amp_curve.sample(t)) as f32;
            }
        });
        finish(&mut out, 0.85, 0.005);
        to_packed(out)
    }

    #[func]
    fn tones(duration: f64, frequency_curves: VarArray, options: VarDictionary) -> PackedFloat32Array {
        let squareness = option_f64(&options, "square", 0.0);
        let tremolo: Vec<f64> = option_array(&options, "tremolo").iter_shared().map(|v| variant_f64(&v)).collect();
        let curves: Vec<Curve> = frequency_curves.iter_shared().map(|c| Curve::from_array(&c.to::<VarArray>())).collect();
        let amp_curve = option_curve(&options, "amp");
        let mut phases = vec![0.0f64; curves.len()];
        let mut out = vec![0.0f32; sample_count(duration)];
        for (i, sample) in out.iter_mut().enumerate() {
            let t = i as f64 / SAMPLE_RATE;
            let mut sum = 0.0;
            for (phase, curve) in phases.iter_mut().zip(&curves) {
                *phase += curve.sample(t) / SAMPLE_RATE;
                sum += softclip((TAU * *phase).sin(), squareness * 6.0);
            }
            let mut amplitude = amp_curve.sample(t);
            if !tremolo.is_empty() {
                let wobble = 0.5 + 0.5 * (TAU * tremolo[0] * t).sin();
                amplitude *= 1.0 - tremolo[1] + tremolo[1] * wobble;
            }
            *sample = (sum / curves.len() as f64 * amplitude) as f32;
        }
        finish(&mut out, option_f64(&options, "peak", 0.85), option_f64(&options, "fade", 0.005));
        to_packed(out)
    }

    #[func]
    fn noise_sweep(duration: f64, options: VarDictionary, mut rng: Gd<RandomNumberGenerator>) -> PackedFloat32Array {
        let highpass_cutoff = option_f64(&options, "highpass", 0.0);
        let lowpass_cutoff = option_f64(&options, "lowpass", 0.0);
        let frequency_curve = option_curve(&options, "freq");
        let q_curve = option_curve(&options, "q");
        let amp_curve = option_curve(&options, "amp");
        let mut band = Formant::default();
        let mut highpass = HighPass::tuned(highpass_cutoff.max(1.0));
        let mut lowpass = LowPass::tuned(lowpass_cutoff.max(1.0));
        let mut out = vec![0.0f32; sample_count(duration)];
        with_rng(&mut rng, |rng| {
            for (i, sample) in out.iter_mut().enumerate() {
                let t = i as f64 / SAMPLE_RATE;
                let mut n = rng.noise();
                if highpass_cutoff > 0.0 {
                    n = highpass.step(n);
                }
                if lowpass_cutoff > 0.0 {
                    n = lowpass.step(n);
                }
                *sample = (band.process(n, frequency_curve.sample(t), q_curve.sample(t)) * amp_curve.sample(t)) as f32;
            }
        });
        finish(&mut out, option_f64(&options, "peak", 0.85), option_f64(&options, "fade", 0.005));
        to_packed(out)
    }

    #[func]
    fn thump(duration: f64, cutoff: f64, attack: f64, decay: f64, mut rng: Gd<RandomNumberGenerator>) -> PackedFloat32Array {
        let mut lowpass = LowPass::tuned(cutoff);
        let mut out = vec![0.0f32; sample_count(duration)];
        with_rng(&mut rng, |rng| {
            for (i, sample) in out.iter_mut().enumerate() {
                let t = i as f64 / SAMPLE_RATE;
                let envelope = if t < attack { t / attack } else { (1.0 - (t - attack) / decay).max(0.0) };
                *sample = (lowpass.step(rng.noise()) * envelope * envelope) as f32;
            }
        });
        to_packed(out)
    }

    #[func]
    fn mixed(samples: PackedFloat32Array, other: PackedFloat32Array, offset: i64, gain: f64) -> PackedFloat32Array {
        let mut out = samples.to_vec();
        mix_into(&mut out, other.as_slice(), offset as usize, gain);
        to_packed(out)
    }

    #[func]
    fn finished(samples: PackedFloat32Array, peak: f64, fade_time: f64) -> PackedFloat32Array {
        let mut out = samples.to_vec();
        finish(&mut out, peak, fade_time);
        to_packed(out)
    }

    #[func]
    fn to_s16_bytes(samples: PackedFloat32Array) -> PackedByteArray {
        let bytes: Vec<u8> = samples
            .as_slice()
            .iter()
            .flat_map(|&s| (((s as f64).clamp(-1.0, 1.0) * 32767.0) as i16).to_le_bytes())
            .collect();
        PackedByteArray::from(bytes)
    }
}

/// Additive band-limited buzz: harmonics of `frequency` at 1/k^rolloff.
pub fn buzz(phase: f64, frequency: f64, max_harmonics: i64, rolloff: f64) -> f64 {
    let count = max_harmonics.min(((SAMPLE_RATE / 2.0 - 200.0) / frequency) as i64);
    let mut sum = 0.0;
    for k in 1..=count {
        sum += (TAU * k as f64 * phase).sin() / (k as f64).powf(rolloff);
    }
    sum
}
