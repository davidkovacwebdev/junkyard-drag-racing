shader_type canvas_item;

// Night color grade, driven by NightOverlay from DayNightCycle.get_night_factor().
// Put this on a full-screen ColorRect that sits ABOVE the world but BELOW the HUD
// (e.g. its own CanvasLayer), since it samples and regrades what's already drawn.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// --- Driven from script ---
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;

// --- Overall look ---
// Multiplied into the scene: this is the "moonlight" color, not a flat overlay.
uniform vec4 night_color : source_color = vec4(0.42, 0.52, 0.95, 1.0);
// Max blend between the day image and the night grade (keeps the world readable).
uniform float max_opacity : hint_range(0.0, 1.0) = 0.9;
// How much the scene darkens at full night.
uniform float darkness : hint_range(0.0, 1.0) = 0.5;
// How much color drains away at full night.
uniform float desaturation : hint_range(0.0, 1.0) = 0.45;
// Blue-ish lift in the shadows so blacks never go dead.
uniform vec4 shadow_tint : source_color = vec4(0.03, 0.05, 0.14, 1.0);

// --- Light preservation (torches, windows, glowing things) ---
uniform float light_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float light_preserve : hint_range(0.0, 1.0) = 0.85;

// --- Vignette ---
uniform float vignette_strength : hint_range(0.0, 1.0) = 1;
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.1;   // was 0.25
uniform float vignette_outer : hint_range(0.0, 1.5) = 0.6;   // was 0.85

// --- Transition ---
// 1.0 = plain smoothstep ease. Higher = holds the day look longer before fading.
uniform float fade_curve : hint_range(0.5, 3.0) = 1.0;

// Interleaved gradient noise: cheap, stable dither with no visible pattern.
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec3 src = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;

	// Eased strength so dusk/dawn don't feel linear.
	float t = smoothstep(0.0, 1.0, pow(night_factor, fade_curve));
	float strength = t * max_opacity;

	float lum = dot(src, vec3(0.299, 0.587, 0.114));

	// 1) Drain color.
	vec3 grade = mix(src, vec3(lum), desaturation);

	// 2) Moonlight multiply + darken, then lift shadows toward a cool tint.
	grade *= night_color.rgb * (1.0 - darkness);
	grade += shadow_tint.rgb * (1.0 - lum);

	// 3) Bright pixels resist the night, so light sources still pop.
	float glow = smoothstep(light_threshold, 1.0, lum);
	grade = mix(grade, src, glow * light_preserve);

	// 4) Vignette (aspect-corrected so it's round, not oval).
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float vig = smoothstep(vignette_inner, vignette_outer, length(uv));
	grade *= 1.0 - vig * vignette_strength;

	// 5) Blend with the day image, then dither to kill banding.
	vec3 result = mix(src, grade, strength);
	result += (ign(FRAGCOORD.xy) - 0.5) / 255.0 * 2.0 * strength;

	COLOR = vec4(result, 1.0);
}
