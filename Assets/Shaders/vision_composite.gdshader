shader_type canvas_item;
render_mode unshaded;

#include "res://Assets/Shaders/vision_field.gdshaderinc"

group_uniforms NoTouchy;

uniform vec4 mask_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

group_uniforms GradientMapping;

uniform sampler2D gradient;
uniform float mix_amount = 1.0;
uniform float color_noise = 0.0;

group_uniforms;

void fragment() {
	float seen = vision_visibility(UV);
	vec2 cell = floor(UV * 64.0);
	vec3 grain = vec3(
		vision_noise(cell, TIME),
		vision_noise(cell + 7.3, TIME),
		vision_noise(cell + 19.1, TIME)) - 0.5;

	vec3 world = clamp(texture(TEXTURE, UV).rgb + grain * color_noise * seen, vec3(0.0), vec3(1.0));
	float hidden = (1.0 - seen) * mask_color.a;
	vec4 input_color = vec4(mix(world, mask_color.rgb, hidden), 1.0);
	float greyscale_value = dot(input_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sampled_color = texture(gradient, vec2(greyscale_value, 0.0)).rgb;
	
	COLOR.rgb = mix(input_color.rgb, sampled_color, mix_amount);
	COLOR.a = input_color.a;
}