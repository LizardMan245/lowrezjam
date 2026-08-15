shader_type canvas_item;
render_mode unshaded;

uniform float noise_amount = 0.55;
uniform float band_speed = 9.0;
uniform vec4 tint : source_color = vec4(0.75, 0.8, 0.85, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float grain = hash(floor(UV * 64.0) + floor(vec2(TIME * 30.0)));
	float band = smoothstep(0.35, 0.0, abs(fract(UV.y - TIME * band_speed * 0.05) - 0.5));
	float level = mix(0.08, 1.0, grain * noise_amount) + band * 0.25;
	COLOR = vec4(tint.rgb * level, 1.0);
}
