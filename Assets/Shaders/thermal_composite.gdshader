shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "res://Assets/Shaders/vision_field.gdshaderinc"

group_uniforms Thermal;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D world_tex : hint_default_black, filter_nearest;
uniform sampler2D heat_gradient;
uniform sampler2D env_gradient;
uniform float grain_amount = 0.07;

group_uniforms;

void fragment() {
	vec4 world = texture(world_tex, UV);
	float lit = clamp(world.r * world.a, 0.0, 1.0);
	vec3 heat_px = texture(TEXTURE, UV).rgb;
	float heat = clamp(dot(heat_px, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);

	float seen = vision_visibility(UV);
	float grain = (vision_noise(floor(UV * 64.0), TIME) - 0.5) * grain_amount * seen;
	lit = clamp(lit + grain, 0.0, 1.0);

	vec3 mapped = mix(
		texture(env_gradient, vec2(lit, 0.0)).rgb,
		texture(heat_gradient, vec2(heat, 0.0)).rgb,
		heat);

	vec3 under = texture(screen_tex, SCREEN_UV).rgb;
	vec3 screened = 1.0 - (1.0 - under) * (1.0 - mapped);

	COLOR = vec4(mix(under, screened, seen), 1.0);
}
