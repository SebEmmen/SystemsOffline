
shader_type canvas_item;

uniform vec4 bottom_color : source_color = vec4(0.35, 0.20, 0.12, 1.0);

uniform float cutoff : hint_range(0.0, 1.0) = 0.85;

uniform float age_strength : hint_range(0.0, 1.0) = 0.35;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;

uniform vec4 paper_tint : source_color = vec4(0.82, 0.70, 0.48, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec4 original = texture(TEXTURE, UV);

    // Aged paper
    vec3 color = mix(
        original.rgb,
        original.rgb * paper_tint.rgb,
        age_strength
    );

    float grain = hash(floor(UV / TEXTURE_PIXEL_SIZE));
    color += (grain - 0.5) * grain_strength;

    // Sharp horizontal cutoff
    if (UV.y >= cutoff) {
        COLOR = bottom_color;
    } else {
        COLOR = vec4(clamp(color, 0.0, 1.0), original.a);
    }
}
