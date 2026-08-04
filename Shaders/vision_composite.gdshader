shader_type canvas_item;
render_mode unshaded;

#include "res://Shaders/vision_field.gdshaderinc"

uniform vec4 mask_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec3 world = texture(TEXTURE, UV).rgb;
	float hidden = (1.0 - vision_visibility(UV)) * mask_color.a;
	COLOR = vec4(mix(world, mask_color.rgb, hidden), 1.0);
}
