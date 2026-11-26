shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_tex : source_color, filter_linear;
uniform int rotation_steps : hint_range(0, 3) = 1;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	for (int i = 0; i < rotation_steps; i++) {
		uv = vec2(uv.y, -uv.x);
	}
	uv += vec2(0.5);
	ALBEDO = texture(screen_tex, uv).rgb;
}