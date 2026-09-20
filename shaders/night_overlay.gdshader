shader_type canvas_item;

// Full-screen dark-blue tint, faded in/out by NightOverlay from
// DayNightCycle.get_night_factor(). max_opacity keeps it a tint rather than
// a blackout — the world stays readable at full night.
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 night_color : source_color = vec4(0.05, 0.08, 0.28, 1.0);
uniform float max_opacity : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	COLOR = vec4(night_color.rgb, night_color.a * night_factor * max_opacity);
}
