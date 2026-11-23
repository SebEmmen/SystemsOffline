
shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float scanline_strength : hint_range(0.0, 0.3) = 0.055;
uniform float scanline_count : hint_range(100.0, 1000.0) = 450.0;
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.012;
uniform float scan_speed : hint_range(0.0, 1.0) = 0.12;
uniform float scan_band_strength : hint_range(0.0, 0.15) = 0.025;

void fragment() {
    vec2 uv = SCREEN_UV;

    vec3 col = texture(screen_texture, uv).rgb;

    // Thin horizontal scanlines
    float lines = sin(uv.y * scanline_count * 6.283185);
    float scanlines = (lines * 0.5 + 0.5) * scanline_strength;

    // Very subtle screen brightness flicker
    float flicker = sin(TIME * 47.0) * flicker_strength;

    // A wide, slowly moving horizontal light band
    float band_position = fract(TIME * scan_speed);
    float band_distance = abs(uv.y - band_position);
    band_distance = min(band_distance, 1.0 - band_distance);

    float band = exp(-band_distance * band_distance * 220.0);
    band *= scan_band_strength;

    // Darken scanlines, then add flicker and moving band
    col *= 1.0 - scanlines + flicker + band;

    COLOR = vec4(col, 1.0);
}
