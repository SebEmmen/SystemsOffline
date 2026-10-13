shader_type spatial;
render_mode unshaded, blend_add; // Notice depth_test_disabled is removed!

uniform vec4 glow_color : source_color = vec4(0.2, 0.7, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.0;       // Higher power = thinner edge
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float min_intensity : hint_range(0.0, 1.0) = 0.1;       // Lowered to reduce harshness
uniform float max_intensity : hint_range(0.5, 5.0) = 0.8;       // Lowered so it's not blinding

void fragment() {
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
    float pulse = mix(min_intensity, max_intensity, (sin(TIME * pulse_speed) + 1.0) * 0.5);
    
    ALBEDO = glow_color.rgb * pulse * fresnel;
}