shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 light_color : source_color = vec4(0.75, 0.98, 1.0, 1.0);

// 0 = off and invisible, 1 = fully lit (set by WireSocket.set_light_progress)
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform float glow_strength : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    ALBEDO = light_color.rgb;
    ALPHA = progress;

    METALLIC = 0.0;
    ROUGHNESS = 0.2;

    EMISSION = light_color.rgb * glow_strength * progress;
}
