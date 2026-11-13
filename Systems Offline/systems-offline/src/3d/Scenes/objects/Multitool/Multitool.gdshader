shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 0.8, 1.0, 1.0); // Sci-fi communication color
uniform float emission_energy : hint_range(0.0, 32.0) = 4.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float activation : hint_range(0.0, 1.0) = 0.0; // 0 = off, 1 = fully active

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * base_color;
	ALBEDO = tex.rgb;
	
	// Subtle breathing pulse effect when active
	float pulse = 1.0 + 0.2 * sin(TIME * pulse_speed);
	
	// Multiply emission by the activation uniform so it can be smoothly tweened
	EMISSION = glow_color.rgb * emission_energy * pulse * activation;
}