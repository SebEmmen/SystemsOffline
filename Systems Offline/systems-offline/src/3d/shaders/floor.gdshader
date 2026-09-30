shader_type spatial;

uniform sampler2D floor_texture : source_color;

varying vec3 world_position;

float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV;

	float rand = random(floor(world_position.xz / 2.0));

	if (rand > 0.5) {
		uv.x = 1.0 - uv.x;
	}

	ALBEDO = texture(floor_texture, uv).rgb;
}