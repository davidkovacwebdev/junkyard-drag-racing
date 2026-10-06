use godot::classes::RandomNumberGenerator;
use godot::prelude::*;

const MULTIPLIER: u64 = 6364136223846793005;
const INCREMENT: u64 = (1442695040888963407u64 << 1) | 1;

/// Godot's RandomPCG, step for step, so noise drawn here continues the exact
/// sequence of the RandomNumberGenerator it was borrowed from and seeded sounds
/// render the same as they did in GDScript.
pub struct Pcg {
    state: u64,
}

impl Pcg {
    /// Same as `RandomNumberGenerator.seed = seed`.
    pub fn from_seed(seed: u64) -> Self {
        let mut pcg = Pcg { state: 0 };
        pcg.next_u32();
        pcg.state = pcg.state.wrapping_add(seed);
        pcg.next_u32();
        pcg
    }

    fn next_u32(&mut self) -> u32 {
        let old_state = self.state;
        self.state = old_state.wrapping_mul(MULTIPLIER).wrapping_add(INCREMENT);
        let xorshifted = (((old_state >> 18) ^ old_state) >> 27) as u32;
        xorshifted.rotate_right((old_state >> 59) as u32)
    }

    pub fn randf(&mut self) -> f64 {
        let exponent_source = self.next_u32();
        if exponent_source == 0 {
            return 0.0;
        }
        let significand = (self.next_u32() | 0x8000_0001) as f32;
        let scale = 2f64.powi(-32 - exponent_source.leading_zeros() as i32);
        ((significand as f64 * scale) as f32) as f64
    }

    /// `randf_range(-1.0, 1.0)`, which Godot computes in single precision.
    pub fn noise(&mut self) -> f64 {
        let unit = self.randf() as f32;
        (unit * 2.0f32 + -1.0f32) as f64
    }
}

/// Runs `body` with a Pcg that continues `rng`, then hands the advanced state
/// back so the GDScript side carries on from where the native code stopped.
pub fn with_rng<T>(rng: &mut Gd<RandomNumberGenerator>, body: impl FnOnce(&mut Pcg) -> T) -> T {
    let mut pcg = Pcg { state: rng.get_state() };
    let result = body(&mut pcg);
    rng.set_state(pcg.state);
    result
}
