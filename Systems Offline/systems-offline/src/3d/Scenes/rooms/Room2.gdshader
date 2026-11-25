shader_type spatial;

uniform sampler2D wall_texture : source_color;

void fragment() {
    vec2 rotated_uv = vec2(UV.y, 1.0 - UV.x);
    ALBEDO = texture(wall_texture, rotated_uv).rgb;
}
