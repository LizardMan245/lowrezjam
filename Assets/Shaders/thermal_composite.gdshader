shader_type canvas_item;
render_mode unshaded, blend_add;

#include "res://Assets/Shaders/vision_field.gdshaderinc"

group_uniforms Thermal;

uniform sampler2D heat_gradient;
uniform sampler2D world_tex : hint_default_black, filter_nearest;
uniform float blur_radius = 2.5;
uniform float heat_gain = 1.6;
uniform float env_floor = 0.02;
uniform float env_ceiling = 0.16;
uniform float env_mix = 0.5;

group_uniforms;

const int BLUR_TAPS = 2;

void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * blur_radius;
	float heat = 0.0;
	float weight = 0.0;

	for (int y = -BLUR_TAPS; y <= BLUR_TAPS; y++) {
		for (int x = -BLUR_TAPS; x <= BLUR_TAPS; x++) {
			vec2 offset = vec2(float(x), float(y));
			float fade = 1.0 - length(offset) / float(BLUR_TAPS + 1);
			if (fade <= 0.0) {
				continue;
			}
			heat += texture(TEXTURE, UV + offset * step_size).a * fade;
			weight += fade;
		}
	}

	heat = clamp(heat / max(weight, 0.0001) * heat_gain, 0.0, 1.0);

	float world_lit = dot(texture(world_tex, UV).rgb, vec3(0.299, 0.587, 0.114));
	float environment = smoothstep(env_floor, env_ceiling, world_lit) * env_mix;

	float total = clamp(max(heat, environment), 0.0, 1.0);
	vec3 mapped = texture(heat_gradient, vec2(total, 0.0)).rgb;

	COLOR = vec4(mapped, total * vision_visibility(UV));
}
