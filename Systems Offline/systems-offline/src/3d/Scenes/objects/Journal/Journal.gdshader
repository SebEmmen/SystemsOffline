
shader_type canvas_item;

// Aging controls
uniform float age_strength : hint_range(0.0, 1.0) = 0.35;
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.25;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform float stain_strength : hint_range(0.0, 1.0) = 0.15;

uniform vec4 paper_tint : source_color = vec4(0.82, 0.70, 0.48, 1.0);

// Random noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    f = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec3 color = original.rgb;

    // Warm, aged paper tint
    color = mix(
        color,
        color * paper_tint.rgb,
        age_strength
    );

    // Darker edges
    vec2 edge = min(UV, 1.0 - UV);
    float distance_to_edge = min(edge.x, edge.y);

    float edge_mask = 1.0 - smoothstep(
        0.0,
        0.18,
        distance_to_edge
    );

    color *= 1.0 - edge_mask * edge_darkness;

    // Large, uneven discoloration
    float stains = noise(UV * 3.0);
    stains *= noise(UV * 5.0);

    color *= 1.0 - stains * stain_strength;

    // Fine paper grain
    float grain = hash(floor(UV / TEXTURE_PIXEL_SIZE));
    color += (grain - 0.5) * grain_strength;

    // Preserve original transparency
    COLOR = vec4(clamp(color, 0.0, 1.0), original.a);
}
