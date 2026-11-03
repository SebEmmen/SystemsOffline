
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.01, 0.05, 0.03, 0);
uniform vec4 stripe_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);

uniform float stripe_count = 1.0;
uniform float stripe_speed = 0.1;
uniform float glow_strength = 0.1;

// Controls how visible the stripes are
uniform float stripe_opacity : hint_range(0.0, 1.0) = 0.005;

void fragment() {
    vec2 uv = UV;

    float pattern = fract(
        (uv.x + uv.y) * stripe_count
        - TIME * stripe_speed
    );

    float stripes = step(0.5, pattern);

    float pulse = 0.8 + 0.2 * sin(TIME * 3.0);

    float effect = stripes * pulse * stripe_opacity;

    ALBEDO = mix(
        base_color.rgb,
        stripe_color.rgb,
        effect
    );

    EMISSION = stripe_color.rgb
        * effect
        * glow_strength;

    METALLIC = 0.4;
    ROUGHNESS = 0.3;
}
