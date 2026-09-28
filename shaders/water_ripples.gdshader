shader_type canvas_item;
// The ocean fill plus its drifting ripple strokes, worked out per pixel so the
// whole visible sea is one rect. Mirrors the grid layout Water used to draw
// stroke by stroke: see water.gd for what each value means.

uniform vec4 deep_color : source_color;
uniform vec4 ripple_color : source_color;
uniform float ripple_width = 5.0;
uniform float ripple_length = 96.0;
uniform float ripple_spacing = 260.0;
uniform float ripple_row_offset = 0.5;
uniform float drift = 0.0;
uniform float wave_time = 0.0;
uniform float bob_speed = 0.9;
uniform float bob_height = 16.0;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

float ripple_coverage(vec2 point, float row, float col, float head_x, float pixel) {
	float bob = sin(wave_time * bob_speed + row * 1.7 + col * 0.8);
	vec2 head = vec2(head_x, row * ripple_spacing + bob * bob_height);
	float along = point.x - head.x;
	float across = abs(point.y - head.y);
	float inside_length = smoothstep(-pixel, pixel, along) * (1.0 - smoothstep(ripple_length - pixel, ripple_length + pixel, along));
	float inside_width = 1.0 - smoothstep(ripple_width * 0.5 - pixel, ripple_width * 0.5 + pixel, across);
	return inside_length * inside_width;
}

void fragment() {
	vec2 point = local_position;
	float pixel = max(fwidth(point.x), 0.0001) * 0.5;
	float coverage = 0.0;
	float nearest_row = floor(point.y / ripple_spacing);
	// A bobbing stroke can stray into the next row band, so check both neighbours.
	for (int row_step = -1; row_step <= 1; row_step++) {
		float row = nearest_row + float(row_step);
		float start = ripple_spacing * ripple_row_offset * mod(row, 2.0) + drift;
		float col = floor((point.x - start) / ripple_spacing);
		for (int col_step = -1; col_step <= 0; col_step++) {
			float c = col + float(col_step);
			coverage = max(coverage, ripple_coverage(point, row, c, c * ripple_spacing + start, pixel));
		}
	}
	COLOR = vec4(mix(deep_color.rgb, ripple_color.rgb, ripple_color.a * coverage), deep_color.a);
}
