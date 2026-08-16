shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;

uniform sampler2D source : source_color, filter_nearest;

void fragment() {
	vec4 tex = texture(source, UV);
	ALBEDO = 1.0 - tex.rgb;
	ALPHA = tex.a;
}
