shader_type spatial;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float fresnel_power : hint_range(1.0, 20.0) = 8.0;       // High power = ultra-thin edge highlight
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;          // Slow, gentle breathing
uniform float min_intensity : hint_range(0.0, 1.0) = 0.10;       // Very faint base level
uniform float max_intensity : hint_range(0.0, 1.0) = 0.30;       // Low peak brightness

void fragment() {
    // Sharp rim curve to confine glow strictly to outer contours
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
    
    // Smooth, gentle pulse
    float pulse = mix(min_intensity, max_intensity, (sin(TIME * pulse_speed) + 1.0) * 0.5);
    
    ALBEDO = glow_color.rgb * pulse * fresnel;
}