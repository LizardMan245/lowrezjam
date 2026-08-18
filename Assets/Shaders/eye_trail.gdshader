shader_type particles;

void start() {
	CUSTOM.xyz = EMISSION_TRANSFORM[3].xyz;
}

void process() {
	float spacing = 0.125;
	
	for (int i = 0; i < int(distance(EMISSION_TRANSFORM[3].xyz, CUSTOM.xyz) / spacing); i++) {
		CUSTOM.xyz += normalize(EMISSION_TRANSFORM[3].xyz - CUSTOM.xyz) * spacing;
		
		mat4 custom_transform = mat4(1.0);
		custom_transform[3].xyz = CUSTOM.xyz;
		emit_subparticle(custom_transform, vec3(0.0), vec4(0.0), vec4(0.0), FLAG_EMIT_POSITION);
	}
}