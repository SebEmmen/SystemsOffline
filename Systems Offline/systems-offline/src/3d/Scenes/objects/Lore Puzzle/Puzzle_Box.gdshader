shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_tex : source_color, filter_linear;

void fragment() {
    vec2 uv = vec2(1.0 - UV.y, UV.x);   // rotate the texture back 90 degrees
    ALBEDO = texture(screen_tex, uv).rgb;
}