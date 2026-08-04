shader_type canvas_item;
render_mode unshaded;

// Normal vision. Runs on the SubViewportContainer holding the 3D world, so it
// is applied to the finished frame -- after glow, tonemapping and everything
// else the environment does, and under the player overlay drawn on top of it.

#include "res://Shaders/vision_field.gdshaderinc"

uniform vec4 mask_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec3 world = texture(TEXTURE, UV).rgb;
	float hidden = (1.0 - vision_visibility(UV)) * mask_color.a;
	COLOR = vec4(mix(world, mask_color.rgb, hidden), 1.0);
}
