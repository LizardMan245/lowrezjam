shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;

uniform sampler2D source : source_color, filter_nearest;
uniform bool invert = false;
uniform bool flatten = false;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(source, UV);
	vec3 rgb = invert ? 1.0 - tex.rgb : tex.rgb;
	ALBEDO = (flatten ? tint.rgb : rgb * tint.rgb);
	ALPHA = tex.a * tint.a;
}
