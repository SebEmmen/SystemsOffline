shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Disconnected wire (only visible if disconnected_alpha > 0)
uniform vec4 disconnected_color : source_color =
    vec4(0.95, 0.97, 1.0, 1.0);

// Opacity of the core while disconnected (0 = fully invisible)
uniform float disconnected_alpha : hint_range(0.0, 1.0) = 0.0;

// Very light cyan body
uniform vec4 connected_body_color : source_color =
    vec4(0.75, 0.98, 1.0, 1.0);

// Almost pure white core
uniform vec4 connected_core_color : source_color =
    vec4(1.0, 1.0, 1.0, 1.0);

// Activation animation
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float transition_width : hint_range(0.001, 0.3) = 0.08;

// Brightness
uniform float glow_strength : hint_range(0.0, 10.0) = 1.8;
uniform float core_brightness : hint_range(0.0, 5.0) = 1.4;

// Controls how much of the wire appears white
uniform float core_width : hint_range(0.0, 1.0) = 0.75;

// true  = core is centred in the view and fades at the silhouette
// false = original UV.x stripe along one side of the tube
uniform bool fresnel_core = true;

// Subtle edge shading
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.08;

void fragment() {

    // Electricity travels along the wire.
    // Range is stretched so progress = 1.0 fully covers the tip (UV.y = 1.0).
    float p = progress * (1.0 + transition_width);
    float activation = 1.0 - smoothstep(
        p - transition_width,
        p,
        UV.y
    );

    // 0 in the middle of the tube, 1 at the edges
    float centered_u;
    if (fresnel_core) {
        centered_u = 1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
    } else {
        centered_u = abs(UV.x - 0.5) * 2.0;
    }

    // Bright white core with slightly cyan edges
    float core_mask = 1.0 - smoothstep(
        core_width * 0.5,
        core_width,
        centered_u
    );

    // Connected appearance
    vec3 body = connected_body_color.rgb
        * (1.0 - edge_darkness);

    vec3 connected_color = mix(
        body,
        connected_core_color.rgb,
        core_mask
    );

    // Disconnected to connected transition
    ALBEDO = mix(
        disconnected_color.rgb,
        connected_color,
        activation
    );

    // See-through when disconnected, solid where the electricity has reached
    ALPHA = mix(disconnected_alpha, 1.0, activation);

    METALLIC = 0.0;
    ROUGHNESS = 0.12;
    SPECULAR = 0.7;

    // White-dominant emission with a soft cyan tint
    vec3 emission_color = mix(
        connected_body_color.rgb,
        connected_core_color.rgb,
        core_mask
    );

    EMISSION = emission_color
        * glow_strength
        * activation
        * mix(0.55, core_brightness, core_mask);
}
