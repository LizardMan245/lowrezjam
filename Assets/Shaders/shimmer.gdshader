shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float distortion = 0.035;
uniform float edge_sharpness = 1.6;
uniform vec4 tint : source_color = vec4(0.55, 0.72, 1.0, 0.18);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 centred = UV * 2.0 - 1.0;
	float blob = clamp(1.0 - dot(centred, centred), 0.0, 1.0);
	vec2 offset = centred * distortion * blob;
	vec3 behind = texture(screen_tex, SCREEN_UV + offset).rgb;

	ALBEDO = mix(behind, tint.rgb, tint.a);
	ALPHA = pow(blob, edge_sharpness);
}
