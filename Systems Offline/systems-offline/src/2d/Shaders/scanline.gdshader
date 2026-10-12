
shader_type canvas_item;

uniform float scanline_count : hint_range(100.0, 1000.0) = 450.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.45;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.65;
uniform bool enabled = true;

void fragment() {
	if (!enabled) {
		COLOR = vec4(0.0);
	} else {
		vec2 uv = SCREEN_UV;

		// Scanlines
		float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		float scan_val = scanline * scanline_intensity;

		// Vignette
		vec2 center_uv = (uv - 0.5) * 2.0;
		float dist = length(center_uv);
		float vignette = smoothstep(0.7, 1.4, dist * vignette_intensity);

		// Subtle cyan tint on edges
		vec3 tint = mix(
			vec3(0.0),
			vec3(0.0, 0.05, 0.1),
			dist * 0.5
		);

		float alpha = clamp(
			scan_val + vignette * vignette_opacity,
			0.0,
			0.8
		);

		COLOR = vec4(tint, alpha);
	}
}
