
shader_type spatial;
render_mode cull_disabled;

uniform vec4 locked_color : source_color = vec4(0.6, 0.0, 0.0, 1.0);
uniform vec4 unlocked_color : source_color = vec4(0.0, 0.8, 0.0, 1.0);

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float transition_width : hint_range(0.001, 0.2) = 0.02;

void fragment() {
    float position = UV.y;

    float blend = 1.0 - smoothstep(
        progress - transition_width,
        progress,
        position
    );

    ALBEDO = mix(
        locked_color.rgb,
        unlocked_color.rgb,
        blend
    );
}
