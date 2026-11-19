
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 hologram_color : source_color = vec4(0.0, 1.0, 0.45, 1.0);

uniform float opacity : hint_range(0.0, 1.0) = 0.25;
uniform float scan_density : hint_range(1.0, 100.0) = 30.0;
uniform float scan_speed : hint_range(-10.0, 10.0) = 1.0;
uniform float scan_angle : hint_range(-90.0, 90.0) = 45.0;

uniform float glow_strength : hint_range(0.0, 10.0) = 2.0;
uniform float glitch_strength : hint_range(0.0, 0.1) = 0.015;

float random(float x) {
    return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // Occasional horizontal glitch displacement
    float row = floor(uv.y * 50.0);

    float glitch = step(
        0.94,
        random(row + floor(TIME * 8.0))
    );

    uv.x += glitch *
        glitch_strength *
        sin(TIME * 20.0);

    // Rotate UV coordinates for diagonal scanlines
    float angle = radians(scan_angle);

    vec2 direction = vec2(
        cos(angle),
        sin(angle)
    );

    float diagonal_uv = dot(uv, direction);

    // Thin diagonal scanlines
    float lines = pow(
        0.5 + 0.5 * sin(
            diagonal_uv * scan_density * 6.28318
            - TIME * scan_speed * 2.0
        ),
        6.0
    );

    // Large moving diagonal energy band
    float scan = pow(
        0.5 + 0.5 * sin(
            diagonal_uv * 12.0
            - TIME * scan_speed * 4.0
        ),
        12.0
    );

    // Bright glowing edges
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

    ALBEDO = hologram_color.rgb;

    EMISSION = hologram_color.rgb *
        brightness *
        glow_strength;

    ALPHA = clamp(
        opacity +
        lines * 0.15 +
        scan * 0.3 +
        edge * 0.4,
        0.0,
        1.0
    );
}
