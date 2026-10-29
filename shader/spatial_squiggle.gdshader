shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
group_uniforms Squiggle;
/**
 * Noise texture scale
 * By default, the noise texture's size in world units is set by its resolution
*/
uniform vec2 scale = vec2(1.0, 1.0);
uniform float strength = 1.0;
/**
 * Number of squiggle frames per second
*/
uniform float fps = 6.0;
uniform sampler2D noise : filter_linear, repeat_enable;
group_uniforms;

group_uniforms Sprite;
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
uniform vec4 modulate : source_color = vec4(1.0);
group_uniforms;

varying vec2 noise_uv;

// Use irrational constants for unique squiggles every frame
#define offset_multiplier vec2(PI, E)

void vertex() {
	// Object-local position keeps the pattern attached to the object
	noise_uv = VERTEX.xy / (vec2(textureSize(noise, 0)) * scale * 0.01);
}

void fragment() {
	vec2 noise_offset = vec2(floor(TIME * fps)) * offset_multiplier;
	float noise_sample = texture(noise, noise_uv + noise_offset).r * 4.0 * PI;
	vec2 direction = vec2(cos(noise_sample), sin(noise_sample));
	vec2 squiggle_uv = UV + direction * strength * 0.005;

	vec4 col = texture(texture_albedo, squiggle_uv) * modulate;
	ALBEDO = col.rgb;
	ALPHA = col.a;
}