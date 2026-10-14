shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform float darken_amount : hint_range(0.0, 1.0) = 0.45;
uniform float desaturation : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.55;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.6;
uniform float scanline_count : hint_range(100.0, 1000.0) = 500.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.05;
uniform vec3 tint_color : source_color = vec3(0.0, 0.04, 0.09);
uniform bool enabled = true;

void fragment() {
	if (!enabled) {
		COLOR = vec4(0.0);
		return;
	}

	vec2 uv = SCREEN_UV;

	// Real-time frosted screen blur
	vec4 base_col = textureLod(screen_texture, uv, blur_amount);

	// Desaturation
	float luma = dot(base_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(base_col.rgb, vec3(luma), desaturation);

	// Darken and apply subtle Kitefin cyan/slate tint
	vec3 tinted = desat * (1.0 - darken_amount) + tint_color;

	// Radial vignette
	vec2 center_uv = (uv - 0.5) * 2.0;
	float dist = length(center_uv);
	float vignette = smoothstep(0.65, 1.5, dist * vignette_intensity);
	tinted = mix(tinted, tinted * 0.35, vignette * vignette_opacity);

	// Subtle CRT scanlines
	float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
	tinted -= scanline * scanline_intensity;

	COLOR = vec4(clamp(tinted, vec3(0.0), vec3(1.0)), 1.0);
}
