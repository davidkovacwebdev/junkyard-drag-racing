shader_type canvas_item;
render_mode blend_mul, unshaded;

// One headlight beam, drawn in the world by Headlights.gd so it y-sorts with
// the car. It leaves the colour alone and multiplies the framebuffer's alpha
// down by how lit each pixel is. Anything drawn later (a house in front of the
// car) is opaque and writes alpha back to 1, so it blocks the light. The night
// overlay then reads `1 - alpha` as the light mask.
//
// UV is (distance along the beam, distance across it) divided by its reach, so
// the lamp sits at (0, 0) and the beam ends at x = 1. COLOR.a is the lamp's power.

uniform float spread : hint_range(0.05, 1.2) = 0.32;
uniform float glow_radius = 0.045;
// Flat light bands instead of a smooth falloff, to match the cut-out art.
uniform float bands : hint_range(1.0, 8.0) = 3.0;

void fragment() {
	float along = UV.x;
	float across = abs(UV.y);
	float half_width = 0.02 + max(along, 0.0) * tan(spread);
	float cone = (1.0 - smoothstep(half_width * 0.55, half_width, across))
			* (1.0 - smoothstep(0.3, 1.0, length(UV)))
			* step(0.0, along);
	float glow = 1.0 - smoothstep(0.0, glow_radius, length(UV));
	float light = max(cone, glow) * COLOR.a;
	light = ceil(light * bands - 0.001) / bands;
	COLOR = vec4(1.0, 1.0, 1.0, 1.0 - light);
}
