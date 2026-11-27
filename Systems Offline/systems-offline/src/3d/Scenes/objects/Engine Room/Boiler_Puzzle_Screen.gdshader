shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D screen_texture : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Screen / CRT styling
uniform float emission_strength : hint_range(0.0, 6.0) = 1.6;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_count : hint_range(16.0, 1080.0) = 240.0;
uniform float scanline_scroll_speed : hint_range(-10.0, 10.0) = 0.4;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;

// Optional active / alert state (0.0 = normal, 1.0 = highlighted/active)
uniform float active_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 active_glow_color : source_color = vec4(0.2, 0.85, 1.0, 1.0);
uniform float active_pulse_speed : hint_range(0.0, 12.0) = 4.0;

void fragment() {
	// Sample the SubViewport texture
	vec3 tex_col = texture(screen_texture, UV).rgb * tint_color.rgb;

	// Subtle horizontal scanlines
	float scan_wave = sin((UV.y * scanline_count + TIME * scanline_scroll_speed) * 3.14159265);
	float scanline = mix(1.0, 0.85 + 0.15 * scan_wave, scanline_intensity);

	// Soft edge vignette around the screen border
	vec2 centered_uv = UV * 2.0 - 1.0;
	float dist = length(centered_uv);
	float vignette = 1.0 - smoothstep(0.65, 1.35, dist) * vignette_strength;

	vec3 final_col = tex_col * scanline * vignette;

	// Optional pulse when active_amount > 0
	float pulse = 1.0 + 0.15 * sin(TIME * active_pulse_speed);
	vec3 active_boost = active_glow_color.rgb * active_amount * pulse * 0.6;

	ALBEDO = final_col;
	EMISSION = (final_col * emission_strength) + active_boost;

	// Keep roughness high and specular low so room lights don't wash out the UI
	ROUGHNESS = 0.75;
	SPECULAR = 0.15;
}