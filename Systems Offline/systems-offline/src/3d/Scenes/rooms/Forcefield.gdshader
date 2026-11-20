
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 hologram_color : source_color = vec4(0.0, 1.0, 0.45, 1.0);

uniform float activation : hint_range(0.0, 1.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.25;

uniform float scan_density : hint_range(1.0, 100.0) = 30.0;
uniform float scan_speed : hint_range(-10.0, 10.0) = 1.0;
uniform float scan_angle : hint_range(-90.0, 90.0) = 45.0;

uniform float glow_strength : hint_range(0.0, 10.0) = 2.0;
uniform float glitch_strength : hint_range(0.0, 0.1) = 0.015;

// Activation controls
uniform float activation_progress : hint_range(0.0, 1.0) = 0.0;
uniform float activation_flicker : hint_range(0.0, 1.0) = 0.0;

uniform float activation_edge_width : hint_range(0.001, 0.2) = 0.04;
uniform float activation_edge_glow : hint_range(0.0, 20.0) = 6.0;


float random(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}


void fragment() {
	vec2 uv = UV;

	// Horizontal glitch displacement
	float row = floor(uv.y * 50.0);

	float glitch = step(
		0.94,
		random(row + floor(TIME * 8.0))
	);

	uv.x += glitch *
		glitch_strength *
		sin(TIME * 20.0);

	// Diagonal scanlines
	float angle = radians(scan_angle);

	vec2 direction = vec2(
		cos(angle),
		sin(angle)
	);

	float diagonal_uv = dot(uv, direction);

	float lines = pow(
		0.5 + 0.5 * sin(
			diagonal_uv * scan_density * 6.28318
			- TIME * scan_speed * 2.0
		),
		6.0
	);

	// Moving energy band
	float scan = pow(
		0.5 + 0.5 * sin(
			diagonal_uv * 12.0
			- TIME * scan_speed * 4.0
		),
		12.0
	);

	// Glowing borders
	float border = min(
		min(uv.x, 1.0 - uv.x),
		min(uv.y, 1.0 - uv.y)
	);

	float edge = 1.0 - smoothstep(
		0.0,
		0.08,
		border
	);

	float brightness =
		lines * 0.3 +
		scan * 1.2 +
		edge * 1.5 +
		glitch * 0.6;

	// Existing forcefield appearance
	vec3 base_emission =
		hologram_color.rgb *
		brightness *
		glow_strength;

	float base_alpha = clamp(
		opacity +
		lines * 0.15 +
		scan * 0.3 +
		edge * 0.4,
		0.0,
		1.0
	);

	// Diagonal activation: bottom-left to top-right.
	float height = (uv.x + (1.0 - uv.y)) * 0.5;


	float activation_mask = 1.0 - smoothstep(
		activation_progress - 0.01,
		activation_progress + 0.01,
		height
	);

	// Bright horizontal activation wave
	float activation_edge = 1.0 - smoothstep(
		0.0,
		activation_edge_width,
		abs(height - activation_progress)
	);

	// Hide the wave when fully off or fully on
	activation_edge *= step(0.001, activation_progress);
	activation_edge *= 1.0 - step(1.0, activation_progress);

	// Apply activation and flickering
	ALBEDO = hologram_color.rgb;

	EMISSION = (
		base_emission * activation_mask +
		hologram_color.rgb *
		activation_edge *
		activation_edge_glow
	) * activation_flicker * activation;

	ALPHA = clamp(
		base_alpha * activation_mask +
		activation_edge * 0.5,
		0.0,
		1.0
	) * activation_flicker * activation;
}
