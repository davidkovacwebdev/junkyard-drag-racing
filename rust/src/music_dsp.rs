//! MusicSynth's band: every instrument, singer and drum, rendered as mono
//! samples (the held note plus its release tail). MusicSynth sequences them.

use godot::classes::RandomNumberGenerator;
use godot::prelude::*;
use std::f64::consts::{PI, TAU};

use crate::dsp::{
    Formant, HighPass, LowPass, SAMPLE_RATE, finish, lerp, lowpass_noise_gain, mix_into, sample_count, smoothstep,
    softclip, state_variable_coefficient, to_packed, variant_f64,
};
use crate::pcg::{Pcg, with_rng};

#[derive(GodotClass)]
#[class(no_init)]
pub struct MusicDsp;

#[godot_api]
impl MusicDsp {
    /// Buzzy comb-and-paper kazoo: a saw scooping up into the pitch, wobbling
    /// vibrato, pushed through two vowel formants with a bit of breath.
    #[func]
    fn kazoo(from_frequency: f64, to_frequency: f64, duration: f64, mut rng: Gd<RandomNumberGenerator>) -> PackedFloat32Array {
        let release = 0.05;
        let mut low_formant = Formant::tuned(650.0, 3.0);
        let mut high_formant = Formant::tuned(1700.0, 4.0);
        let mut breath = LowPass::tuned(3000.0);
        let mut phase = 0.0;
        with_rng(&mut rng, |rng| {
            render(duration + release, |t| {
                let frequency = glide(from_frequency, to_frequency, t, duration);
                let scoop = 1.0 - 0.06 * (1.0 - t / 0.04).max(0.0);
                let vibrato = 1.0 + 0.015 * (TAU * 6.0 * t).sin() * (t / 0.2).min(1.0);
                phase = (phase + frequency * scoop * vibrato / SAMPLE_RATE) % 1.0;
                let saw = 2.0 * phase - 1.0 + breath.step(rng.noise()) * 0.15;
                let voiced = low_formant.step(saw) * 1.2 + high_formant.step(saw) * 0.8 + saw * 0.15;
                softclip(voiced, 1.5) * envelope(t, 0.012, duration, release)
            })
        })
    }

    /// Funk slap bass: a saw/square through a resonant low-pass that snaps shut
    /// after the pluck ("pew"), with a thumb-pop click on top.
    #[func]
    fn slap_bass(from_frequency: f64, to_frequency: f64, duration: f64) -> PackedFloat32Array {
        let release = 0.04;
        let held = duration.min(0.7);
        let (mut low, mut band, mut phase) = (0.0, 0.0, 0.0);
        let damping = 0.25;
        render(held + release, |t| {
            let frequency = glide(from_frequency, to_frequency, t, duration);
            phase = (phase + frequency / SAMPLE_RATE) % 1.0;
            let source = (2.0 * phase - 1.0) * 0.6 + (if phase < 0.5 { 1.0 } else { -1.0 }) * 0.4;
            let coefficient = state_variable_coefficient(250.0 + 2600.0 * (-t * 22.0).exp());
            low += coefficient * band;
            let high = source - low - damping * band;
            band += coefficient * high;
            let pop = (TAU * 1800.0 * t).sin() * (-t * 180.0).exp() * 0.5;
            softclip(low * 0.9 + pop, 0.8) * envelope(t, 0.002, held, release)
        })
    }

    /// Clavinet: a thin pulse wave through a filter that quacks open and shut.
    /// Short and choppy, made for off-beat stabs.
    #[func]
    fn clav(frequency: f64, duration: f64) -> PackedFloat32Array {
        let held = duration.min(0.25);
        let release = 0.03;
        let (mut low, mut band, mut phase) = (0.0, 0.0, 0.0);
        render(held + release, |t| {
            phase = (phase + frequency / SAMPLE_RATE) % 1.0;
            let pulse = if phase < 0.22 { 1.0 } else { -0.3 };
            let coefficient = state_variable_coefficient(3400.0f64.min(700.0 + 3200.0 * (-t * 30.0).exp()));
            low += coefficient * band;
            let high = pulse - low - 0.18 * band;
            band += coefficient * high;
            (band * 0.7 + low * 0.3) * (-t * 6.0).exp() * envelope(t, 0.001, held, release)
        })
    }

    /// Karplus-Strong plucked string: bright twang, quick decay, choked off when
    /// the note ends.
    #[func]
    fn banjo(frequency: f64, duration: f64, mut rng: Gd<RandomNumberGenerator>) -> PackedFloat32Array {
        let ring = duration.min(0.6) + 0.06;
        let period = ((SAMPLE_RATE / frequency).round() as usize).max(2);
        let mut delay_line: Vec<f32> = with_rng(&mut rng, |rng| (0..period).map(|_| rng.noise() as f32).collect());
        let mut index = 0;
        let mut previous = 0.0;
        render(ring, |t| {
            let current = delay_line[index] as f64;
            delay_line[index] = ((current + previous) * 0.5 * 0.994) as f32;
            previous = current;
            index = (index + 1) % period;
            let choke = (1.0 - (t - (ring - 0.06)) / 0.06).clamp(0.0, 1.0);
            current * choke * 0.8
        })
    }

    /// Oom-pah tuba: a few rounded harmonics, a little "blat" on the attack.
    #[func]
    fn tuba(from_frequency: f64, to_frequency: f64, duration: f64) -> PackedFloat32Array {
        let release = 0.08;
        let held = duration.min(0.6);
        let mut lowpass = LowPass::tuned(700.0);
        let mut phase = 0.0;
        render(held + release, |t| {
            let blat = 1.0 + 0.03 * (1.0 - t / 0.04).max(0.0);
            phase += glide(from_frequency, to_frequency, t, duration) * blat / SAMPLE_RATE;
            let tone = (TAU * phase).sin() + 0.5 * (TAU * 2.0 * phase).sin() + 0.3 * (TAU * 3.0 * phase).sin();
            let bright = 1.0 + 1.5 * (1.0 - t / 0.06).max(0.0);
            lowpass.step(softclip(tone * bright, 0.8)) * envelope(t, 0.015, held, release)
        })
    }

    /// Plinky toy piano: a sine plus a clanky out-of-tune partial, both dying fast.
    #[func]
    fn toy_piano(frequency: f64, duration: f64) -> PackedFloat32Array {
        let length = duration.min(0.4) + 0.4;
        render(length, |t| {
            let body = (TAU * frequency * t).sin() * (-t * 5.0).exp();
            let tine = (TAU * frequency * 3.87 * t).sin() * (-t * 18.0).exp() * 0.5;
            let click = (TAU * frequency * 7.1 * t).sin() * (-t * 60.0).exp() * 0.3;
            (body + tine + click) * (t / 0.002).min(1.0) * ((length - t) / 0.05).min(1.0)
        })
    }

    /// Swanee whistle glide between two pitches, breathy and a bit wobbly.
    #[func]
    fn slide_whistle(from_frequency: f64, to_frequency: f64, duration: f64, mut rng: Gd<RandomNumberGenerator>) -> PackedFloat32Array {
        let release = 0.05;
        let mut breath = Formant::default();
        let mut phase = 0.0;
        with_rng(&mut rng, |rng| {
            render(duration + release, |t| {
                let mut frequency = glide(from_frequency, to_frequency, t, duration);
                frequency *= 1.0 + 0.01 * (TAU * 6.0 * t).sin();
                phase += frequency / SAMPLE_RATE;
                let hiss = breath.process(rng.noise(), frequency, 8.0) * 0.4;
                ((TAU * phase).sin() + hiss) * envelope(t, 0.03, duration, release)
            })
        })
    }

    /// Cheesy combo organ: two detuned pulse waves and an octave sine, wobbling
    /// through a cheap tremolo. For chords that shouldn't go together.
    #[func]
    fn organ(frequency: f64, duration: f64, mut rng: Gd<RandomNumberGenerator>) -> PackedFloat32Array {
        let release = 0.05;
        let mut lowpass = LowPass::tuned(2400.0);
        let (mut phase_a, mut phase_b) = with_rng(&mut rng, |rng| (rng.randf(), rng.randf()));
        let mut phase_octave = 0.0;
        render(duration + release, |t| {
            phase_a = (phase_a + frequency / SAMPLE_RATE) % 1.0;
            phase_b = (phase_b + frequency * 1.008 / SAMPLE_RATE) % 1.0;
            phase_octave = (phase_octave + frequency * 2.0 / SAMPLE_RATE) % 1.0;
            let pulses = (if phase_a < 0.4 { 1.0 } else { -1.0 }) * 0.4 + (if phase_b < 0.5 { 1.0 } else { -1.0 }) * 0.4;
            let tremolo = 1.0 + 0.3 * (TAU * 6.3 * t).sin();
            let tone = lowpass.step(pulses) + (TAU * phase_octave).sin() * 0.3;
            tone * tremolo * envelope(t, 0.008, duration, release)
        })
    }

    /// A fat water drop: a sine that swoops up into its pitch with a wet wobble.
    /// The "glup".
    #[func]
    fn bloop(frequency: f64, duration: f64) -> PackedFloat32Array {
        let length = duration.min(0.35) + 0.1;
        let mut phase = 0.0;
        render(length, |t| {
            let swoop = 1.0 - 0.5 * (-t * 26.0).exp();
            let wobble = 1.0 + 0.06 * (TAU * 13.0 * t).sin() * (-t * 5.0).exp();
            phase += frequency * swoop * wobble / SAMPLE_RATE;
            let tone = (TAU * phase).sin() + 0.25 * (TAU * 2.0 * phase).sin() * (-t * 12.0).exp();
            tone * (-t * 6.5).exp() * (t / 0.004).min(1.0) * ((length - t) / 0.03).min(1.0)
        })
    }

    /// A not-quite-human singer: a glottal buzz through three moving vowel
    /// formants, with consonants built from noise bursts, hums and formant
    /// swoops. `parts` is MusicSynth._split_syllable()'s result, `consonants`
    /// its CONSONANTS table and `singer` an entry of SINGERS.
    #[func]
    fn sing_note(
        from_frequency: f64,
        to_frequency: f64,
        duration: f64,
        parts: VarDictionary,
        consonants: VarDictionary,
        singer: VarDictionary,
        mut rng: Gd<RandomNumberGenerator>,
    ) -> PackedFloat32Array {
        let syllable = Syllable::read(&parts, &consonants);
        let singer = Singer::read(&singer);
        let mut out = with_rng(&mut rng, |rng| sing(from_frequency, to_frequency, duration, &syllable, &singer, rng));
        finish(&mut out, 0.8, 0.0);
        to_packed(out)
    }

    /// One drum hit, or several at once (`["k", "h"]`). See MusicSynth's header
    /// for the letters.
    #[func]
    fn drum_hits(names: PackedStringArray, mut rng: Gd<RandomNumberGenerator>) -> PackedFloat32Array {
        let mut out = Vec::new();
        with_rng(&mut rng, |rng| {
            for name in names.as_slice() {
                let (hit, gain) = match name.to_string().as_str() {
                    "k" => (kick(), 1.0),
                    "s" => (snare(rng), 0.6),
                    "z" => (snare(rng), 0.15),
                    "c" => (clap(rng), 0.5),
                    "h" => (hat(0.05, rng), 0.22),
                    "o" => (hat(0.25, rng), 0.2),
                    "g" => (chicken_scratch(rng), 0.35),
                    "t" => (trash_lid(rng), 0.35),
                    "w" => (woodblock(), 0.5),
                    "b" => (boing(), 0.45),
                    "p" => (mouth_pop(), 0.5),
                    "q" => (squeaky_toy(), 0.3),
                    "n" => (saucepan_bonk(), 0.45),
                    "x" => (record_scratch(rng), 0.35),
                    _ => continue,
                };
                mix_into(&mut out, &hit, 0, gain);
            }
        });
        to_packed(out)
    }
}

/// Fill `duration` seconds by calling `sample(t)` for each sample in turn.
fn render(duration: f64, sample: impl FnMut(f64) -> f64) -> PackedFloat32Array {
    to_packed(render_vec(duration, sample))
}

fn render_vec(duration: f64, mut sample: impl FnMut(f64) -> f64) -> Vec<f32> {
    (0..sample_count(duration)).map(|i| sample(i as f64 / SAMPLE_RATE) as f32).collect()
}

/// Exponential pitch bend across the whole note.
fn glide(from_frequency: f64, to_frequency: f64, t: f64, duration: f64) -> f64 {
    if from_frequency == to_frequency {
        return from_frequency;
    }
    from_frequency * (to_frequency / from_frequency).powf(smoothstep(0.0, duration, t))
}

/// Attack ramp, hold for `held`, then a linear release.
fn envelope(t: f64, attack: f64, held: f64, release: f64) -> f64 {
    if t < attack {
        return t / attack;
    }
    if t < held {
        return 1.0;
    }
    (1.0 - (t - held) / release).max(0.0)
}

// --- Singers ------------------------------------------------------------------

#[derive(Clone, Copy, PartialEq)]
enum ConsonantKind {
    Stop,
    VoicedStop,
    Nasal,
    Glide,
    Fricative,
}

struct Consonant {
    kind: ConsonantKind,
    locus: [f64; 3],
    noise: f64,
    length: f64,
    /// Fricatives that keep humming underneath ("z", "v").
    voiced: bool,
}

struct Syllable {
    onset: Vec<Consonant>,
    coda: Vec<Consonant>,
    vowel_from: Option<[f64; 3]>,
    vowel_to: Option<[f64; 3]>,
}

impl Syllable {
    fn read(parts: &VarDictionary, consonants: &VarDictionary) -> Self {
        let letters = |key: &str| -> Vec<Consonant> {
            parts
                .get(key)
                .map_or_else(Array::new, |v| v.to::<Array<GString>>())
                .iter_shared()
                .map(|letter| {
                    let letter = letter.to_string();
                    Consonant::read(&letter, &consonants.get(letter.as_str()).expect("unknown consonant").to::<VarDictionary>())
                })
                .collect()
        };
        let formants = |key: &str| parts.get(key).map(|v| v.to::<VarArray>()).filter(|a| !a.is_empty()).map(|a| triple(&a));
        Syllable {
            onset: letters("onset"),
            coda: letters("coda"),
            vowel_from: formants("vowel_from"),
            vowel_to: formants("vowel_to"),
        }
    }
}

impl Consonant {
    fn read(letter: &str, entry: &VarDictionary) -> Self {
        let kind = match entry.get("kind").map(|v| v.to::<GString>().to_string()).as_deref() {
            Some("stop") => ConsonantKind::Stop,
            Some("voiced_stop") => ConsonantKind::VoicedStop,
            Some("nasal") => ConsonantKind::Nasal,
            Some("fricative") => ConsonantKind::Fricative,
            _ => ConsonantKind::Glide,
        };
        Consonant {
            kind,
            locus: triple(&entry.get("locus").map_or_else(VarArray::new, |v| v.to::<VarArray>())),
            noise: entry.get("noise").map_or(0.0, |v| variant_f64(&v)),
            length: entry.get("length").map_or(0.0, |v| variant_f64(&v)),
            voiced: letter == "z" || letter == "v",
        }
    }
}

fn triple(values: &VarArray) -> [f64; 3] {
    [variant_f64(&values.at(0)), variant_f64(&values.at(1)), variant_f64(&values.at(2))]
}

struct Singer {
    formant_shift: f64,
    vibrato_rate: f64,
    vibrato_depth: f64,
    jitter: f64,
    breath: f64,
    fry: f64,
    scoop: f64,
    crack: f64,
}

impl Singer {
    fn read(entry: &VarDictionary) -> Self {
        let field = |key: &str| entry.get(key).map_or(0.0, |v| variant_f64(&v));
        Singer {
            formant_shift: field("formant_shift"),
            vibrato_rate: field("vibrato_rate"),
            vibrato_depth: field("vibrato_depth"),
            jitter: field("jitter"),
            breath: field("breath"),
            fry: field("fry"),
            scoop: field("scoop"),
            crack: field("crack"),
        }
    }
}

const FORMANT_BANDWIDTHS: [f64; 3] = [90.0, 110.0, 150.0];
const FORMANT_GAINS: [f64; 3] = [1.0, 0.6, 0.35];

fn sing(from_frequency: f64, to_frequency: f64, duration: f64, syllable: &Syllable, singer: &Singer, rng: &mut Pcg) -> Vec<f32> {
    let release = 0.07;
    let onset = &syllable.onset;
    let coda = &syllable.coda;
    let sustained_consonant = syllable.vowel_from.is_none();
    let vowel_from = syllable.vowel_from.unwrap_or_default();
    let vowel_to = syllable.vowel_to.unwrap_or_default();

    let mut onset_lengths: Vec<f64> = onset.iter().map(|c| c.length).collect();
    let onset_total: f64 = onset_lengths.iter().fold(0.0, |sum, length| sum + length);
    let onset_scale = 1.0f64.min((duration * 0.4).min(0.15) / onset_total.max(0.001));
    if sustained_consonant && !onset.is_empty() {
        let last = onset_lengths.len() - 1;
        onset_lengths[last] += duration - onset_total * onset_scale;
    }
    let vowel_start = if !sustained_consonant { onset_total * onset_scale } else { duration };
    let coda_length = if !coda.is_empty() { 0.08f64.min(duration * 0.3) } else { 0.0 };
    let coda_start = duration - coda_length;
    let last_locus = onset.last().map_or(vowel_from, |c| c.locus);

    let shift = singer.formant_shift;
    let mut formant_filters: [Formant; 3] = Default::default();
    let mut noise_filter = Formant::default();
    let mut nasal_filter = LowPass::tuned(350.0 * shift);
    let mut jitter_filter = LowPass::tuned(18.0);
    let jitter_gain = lowpass_noise_gain(18.0);
    let cracks = duration >= 0.3 && rng.randf() < singer.crack;
    let crack_time = duration * 0.55;

    let mut formants = last_locus.map(|f| f * shift);
    let mut voicing = 0.0;
    let mut nasal = 0.0;
    let mut phase = 0.0;
    let mut pulse_index = 0;
    let mut previous_flow = 0.0;
    let mut previous_excitation = 0.0;
    let mut out = vec![0.0f32; sample_count(duration + release)];
    for (i, out_sample) in out.iter_mut().enumerate() {
        let t = i as f64 / SAMPLE_RATE;
        let mut frequency = glide(from_frequency, to_frequency, t, duration);
        frequency *= 2.0f64.powf(singer.scoop / 12.0 * (1.0 - t / 0.09).max(0.0));
        let vibrato_amount = ((t - 0.15) / 0.3).clamp(0.0, 1.0);
        frequency *= 1.0 + singer.vibrato_depth * vibrato_amount * (TAU * singer.vibrato_rate * t).sin();
        frequency *= 1.0 + singer.jitter * jitter_filter.step(rng.noise()) * jitter_gain;
        if cracks && t > crack_time && t < crack_time + 0.09 {
            frequency *= 2.0;
        }

        // What the mouth is doing right now.
        let mut voicing_target = 1.0;
        let mut nasal_target = 0.0;
        let mut noise_amount = 0.0;
        let mut noise_frequency = 2000.0;
        let target: [f64; 3];
        if t < vowel_start || sustained_consonant {
            let mut letter_start = 0.0;
            let mut letter_index = 0;
            while letter_index + 1 < onset.len() && t >= letter_start + onset_lengths[letter_index] * onset_scale {
                letter_start += onset_lengths[letter_index] * onset_scale;
                letter_index += 1;
            }
            let consonant = &onset[letter_index];
            let letter_length = onset_lengths[letter_index] * onset_scale;
            let progress = (t - letter_start) / letter_length.max(0.001);
            target = consonant.locus;
            noise_frequency = consonant.noise;
            match consonant.kind {
                ConsonantKind::Stop => {
                    voicing_target = 0.0;
                    noise_amount = if progress > 0.7 { (-(progress - 0.7) * 12.0).exp() } else { 0.0 };
                }
                ConsonantKind::VoicedStop => {
                    voicing_target = if progress < 0.75 { 0.2 } else { 1.0 };
                    nasal_target = if progress < 0.75 { 1.0 } else { 0.0 };
                    noise_amount = if progress > 0.75 { (-(progress - 0.75) * 14.0).exp() * 0.6 } else { 0.0 };
                }
                ConsonantKind::Nasal => nasal_target = 1.0,
                ConsonantKind::Fricative => {
                    voicing_target = if consonant.voiced { 0.35 } else { 0.0 };
                    noise_amount = 0.5;
                }
                ConsonantKind::Glide => {}
            }
        } else if t < coda_start || coda.is_empty() {
            let into_vowel = smoothstep(vowel_start, coda_start, t);
            let settle = 1.0f64.min((t - vowel_start) / 0.05);
            let glide_amount = smoothstep(0.15, 0.9, into_vowel);
            target = std::array::from_fn(|f| lerp(last_locus[f], lerp(vowel_from[f], vowel_to[f], glide_amount), settle));
        } else {
            let progress = (t - coda_start) / coda_length.max(0.001);
            let consonant = &coda[((progress * coda.len() as f64) as usize).min(coda.len() - 1)];
            target = consonant.locus;
            noise_frequency = consonant.noise;
            match consonant.kind {
                ConsonantKind::Stop | ConsonantKind::VoicedStop => {
                    voicing_target = if progress > 0.4 { 0.0 } else { 1.0 };
                    noise_amount = if progress > 0.75 { (-(progress - 0.75) * 10.0).exp() * 0.5 } else { 0.0 };
                }
                ConsonantKind::Nasal => nasal_target = 1.0,
                ConsonantKind::Fricative => {
                    voicing_target = 0.0;
                    noise_amount = 0.45;
                }
                ConsonantKind::Glide => {}
            }
        }
        if t > duration {
            voicing_target = 0.0;
            noise_amount = 0.0;
        }

        voicing += (voicing_target - voicing) * 0.02;
        nasal += (nasal_target - nasal) * 0.01;
        for f in 0..3 {
            formants[f] += (target[f] * shift - formants[f]) * 0.004;
        }
        if i % 8 == 0 {
            for f in 0..3 {
                formant_filters[f].tune(formants[f], 2.0f64.max(formants[f] / (FORMANT_BANDWIDTHS[f] * shift)));
            }
        }

        phase += frequency / SAMPLE_RATE;
        if phase >= 1.0 {
            phase -= 1.0;
            pulse_index += 1;
        }
        let flow = glottal_flow(phase);
        let mut pulse = (flow - previous_flow) * SAMPLE_RATE / (frequency * 6.0);
        previous_flow = flow;
        if pulse_index % 2 == 1 {
            pulse *= 1.0 - singer.fry;
        }
        let raw_excitation = (pulse + rng.noise() * singer.breath) * voicing;
        // Pre-emphasis, or the upper formants drown and every vowel sounds like "uh".
        let excitation = raw_excitation - 0.94 * previous_excitation;
        previous_excitation = raw_excitation;
        let mut tract = 0.0;
        for f in 0..3 {
            tract += formant_filters[f].step(excitation) * FORMANT_GAINS[f];
        }
        let hum = nasal_filter.step(excitation) * 1.5;
        let mut hiss = 0.0;
        if noise_amount > 0.0 {
            hiss = noise_filter.process(rng.noise(), noise_frequency, 2.5) * noise_amount;
        }
        let sample = lerp(tract * 3.0, hum, nasal) + hiss;
        *out_sample = (softclip(sample, 0.6) * envelope(t, 0.006, duration, release)) as f32;
    }
    out
}

/// Rosenberg glottal pulse: the puff of air through the vocal folds each cycle.
fn glottal_flow(phase: f64) -> f64 {
    if phase < 0.4 {
        return 0.5 * (1.0 - (PI * phase / 0.4).cos());
    }
    if phase < 0.56 {
        return (0.5 * PI * (phase - 0.4) / 0.16).cos();
    }
    0.0
}

// --- Drums --------------------------------------------------------------------

fn kick() -> Vec<f32> {
    let mut phase = 0.0;
    render_vec(0.3, |t| {
        phase += lerp(45.0, 150.0, (-t * 30.0).exp()) / SAMPLE_RATE;
        (TAU * phase).sin() * (-t * 12.0).exp()
    })
}

/// A cardboard-box snare: a dull tonk under a burst of noise.
fn snare(rng: &mut Pcg) -> Vec<f32> {
    let mut highpass = HighPass::tuned(1200.0);
    render_vec(0.18, |t| {
        let noise = highpass.step(rng.noise()) * (-t * 22.0).exp();
        let tonk = (TAU * 185.0 * t).sin() * (-t * 30.0).exp();
        noise + tonk * 0.6
    })
}

/// Three smeared noise slaps, like a handful of people who can't quite clap
/// together.
fn clap(rng: &mut Pcg) -> Vec<f32> {
    let mut band = Formant::tuned(1300.0, 1.5);
    render_vec(0.2, |t| {
        let envelope = if t < 0.033 { (-(t % 0.011) * 300.0).exp() } else { (-(t - 0.033) * 25.0).exp() };
        band.step(rng.noise()) * envelope * 3.0
    })
}

fn hat(length: f64, rng: &mut Pcg) -> Vec<f32> {
    let mut highpass = HighPass::tuned(5000.0);
    render_vec(length, |t| highpass.step(rng.noise()) * (-t * 4.0 / length).exp())
}

/// Muted guitar strings raked with a pick: the funk "chk".
fn chicken_scratch(rng: &mut Pcg) -> Vec<f32> {
    let mut band = Formant::tuned(2400.0, 2.0);
    render_vec(0.045, |t| {
        let body = (TAU * 330.0 * t).sin() * 0.3;
        (band.step(rng.noise()) * 3.0 + body) * (-t * 70.0).exp()
    })
}

/// Hitting a bin lid with a spanner: two clashing metal modes ringing out.
fn trash_lid(rng: &mut Pcg) -> Vec<f32> {
    let mut ring_low = Formant::tuned(1830.0, 40.0);
    let mut ring_high = Formant::tuned(2710.0, 50.0);
    render_vec(0.4, |t| {
        let strike = rng.noise() * (-t * 200.0).exp();
        (ring_low.step(strike) * 6.0 + ring_high.step(strike) * 5.0 + strike * 0.3) * (-t * 7.0).exp()
    })
}

fn woodblock() -> Vec<f32> {
    render_vec(0.08, |t| ((TAU * 880.0 * t).sin() + 0.4 * (TAU * 1370.0 * t).sin()) * (-t * 55.0).exp())
}

/// Cartoon door-stop spring: a rising tone with a fast wobble that dies off.
fn boing() -> Vec<f32> {
    let mut phase = 0.0;
    render_vec(0.6, |t| {
        let frequency = 160.0 * (1.0 + 0.8 * t) * (1.0 + 0.25 * (TAU * 17.0 * t).sin() * (-t * 3.0).exp());
        phase += frequency / SAMPLE_RATE;
        softclip((TAU * phase).sin(), 1.0) * (-t * 5.0).exp() * (t / 0.003).min(1.0)
    })
}

/// Finger flicked out of a cheek: a quick hollow "pok" that drops in pitch.
fn mouth_pop() -> Vec<f32> {
    let mut phase = 0.0;
    render_vec(0.09, |t| {
        phase += lerp(220.0, 620.0, (-t * 60.0).exp()) / SAMPLE_RATE;
        (TAU * phase).sin() * (-t * 45.0).exp() * (t / 0.001).min(1.0)
    })
}

/// Dog toy squeezed twice: "wee-eek".
fn squeaky_toy() -> Vec<f32> {
    let mut squeal = Formant::default();
    let mut phase = 0.0;
    render_vec(0.22, |t| {
        let frequency = 1700.0 + 900.0 * (PI * (t / 0.2).min(1.0)).sin() + 150.0 * (TAU * 38.0 * t).sin();
        phase = (phase + frequency / SAMPLE_RATE) % 1.0;
        let reed = 2.0 * phase - 1.0;
        let envelope = (t / 0.01).min(1.0) * ((0.22 - t) / 0.03).min(1.0) * (0.6 + 0.4 * (TAU * 11.0 * t).sin());
        squeal.process(reed, frequency * 1.5, 3.0) * 2.0 * envelope
    })
}

/// A wooden spoon on an upturned saucepan: a bright clang that bends down.
fn saucepan_bonk() -> Vec<f32> {
    let (mut phase_low, mut phase_high) = (0.0, 0.0);
    render_vec(0.35, |t| {
        let bend = 1.0 + 0.3 * (-t * 40.0).exp();
        phase_low += 540.0 * bend / SAMPLE_RATE;
        phase_high += 1290.0 * bend / SAMPLE_RATE;
        ((TAU * phase_low).sin() * (-t * 11.0).exp() + 0.5 * (TAU * phase_high).sin() * (-t * 18.0).exp()) * (t / 0.001).min(1.0)
    })
}

/// A DJ dragging a record back and forth: noisy tone that swoops down and up.
fn record_scratch(rng: &mut Pcg) -> Vec<f32> {
    let mut band = Formant::default();
    let mut phase = 0.0;
    render_vec(0.25, |t| {
        let speed = (PI * t / 0.25 * 2.0).sin();
        let frequency = 180.0 + 1400.0 * speed.abs();
        phase = (phase + frequency / SAMPLE_RATE) % 1.0;
        let grit = band.process(rng.noise(), frequency * 2.0, 4.0) * 1.5;
        ((2.0 * phase - 1.0) * 0.4 + grit) * speed.abs() * ((0.25 - t) / 0.02).min(1.0)
    })
}
