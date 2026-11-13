
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, repeat_enable;
uniform sampler2D displacement_texture : repeat_enable;
uniform sampler2D normal_texture : hint_normal, repeat_enable;
uniform sampler2D roughness_texture : repeat_enable;

uniform float texture_tiling = 100.0;
uniform float displacement_strength = 0.4;
uniform float height_offset = 0.5;

void vertex() {
    vec2 tiled_uv = UV * texture_tiling;

    float height = texture(
        displacement_texture,
        tiled_uv
    ).r;

    VERTEX.y += (height - height_offset)
        * displacement_strength;
}

void fragment() {
    vec2 tiled_uv = UV * texture_tiling;

    ALBEDO = texture(albedo_texture, tiled_uv).rgb;

    NORMAL_MAP = texture(normal_texture, tiled_uv).rgb;
    NORMAL_MAP_DEPTH = 1.0;

    ROUGHNESS = texture(roughness_texture, tiled_uv).r;
}
