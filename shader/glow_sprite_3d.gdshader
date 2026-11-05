shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform float glow_intensity : hint_range(1.0, 10.0) = 3.0;
uniform bool no_depth = false;

void fragment() {
    vec2 uv = FRONT_FACING ? UV : vec2(1.0 - UV.x, UV.y);
    vec4 color = texture(texture_albedo, uv);

    ALBEDO = color.rgb * glow_intensity;
    ALPHA = color.a;

    // Godot 4 uses reversed-Z: 1.0 = nearest. Forcing 1.0 draws on top of everything.
    DEPTH = no_depth ? 1.0 : FRAGCOORD.z;
}