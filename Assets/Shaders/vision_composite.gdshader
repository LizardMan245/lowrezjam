shader_type canvas_item;
render_mode unshaded;

#include "res://Assets/Shaders/vision_field.gdshaderinc"

uniform vec4 mask_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D gradient;
uniform float mix_amount = 1.0;

void fragment() {
	vec3 world = texture(TEXTURE, UV).rgb;
	float hidden = (1.0 - vision_visibility(UV)) * mask_color.a;
	vec4 input_color = vec4(mix(world, mask_color.rgb, hidden), 1.0);
	float greyscale_value = dot(input_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sampled_color = texture(gradient, vec2(greyscale_value, 0.0)).rgb;
	
	COLOR.rgb = mix(input_color.rgb, sampled_color, mix_amount);
	COLOR.a = input_color.a;
}