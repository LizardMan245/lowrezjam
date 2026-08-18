group_uniforms NoTouchy;

uniform sampler2D vision_ranges : hint_default_white, filter_linear, repeat_disable;

uniform vec2 eye_pos = vec2(0.0);
uniform vec2 eye_dir = vec2(0.0, 1.0);
uniform vec2 eye_right = vec2(1.0, 0.0);
uniform float aperture_width = 0.6;
uniform float half_angle = 0.3926991;
uniform float fan_half_angle = 0.6544985;
uniform float edge_softness = 0.0523599;
uniform float view_distance = 7.0;
uniform float distance_fade = 1.5;
uniform float shadow_softness = 0.05;
uniform float window_shadow = 0.2;

uniform vec3 cam_pos = vec3(0.0, 10.0, 0.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 0.0, -1.0);
uniform vec3 cam_forward = vec3(0.0, -1.0, 0.0);
uniform vec2 cam_half_extents = vec2(5.0);
uniform float ground_height = 0.0;

group_uniforms;

float vision_noise(vec2 cell, float seed) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233)) + seed * 43.7585) * 43758.5453);
}

vec2 vision_ground_point(vec2 uv) {
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	vec3 origin = cam_pos
		+ cam_right * (ndc.x * cam_half_extents.x)
		+ cam_up * (ndc.y * cam_half_extents.y);
	float t = abs(cam_forward.y) < 0.0001 ? 0.0 : (ground_height - origin.y) / cam_forward.y;
	return (origin + cam_forward * t).xz;
}

float vision_angle_to(vec2 direction) {
	return atan(
		eye_dir.y * direction.x - eye_dir.x * direction.y,
		dot(eye_dir, direction));
}

vec2 vision_origin(int index, int count) {
	if (count < 2) {
		return eye_pos;
	}
	float offset = float(index) / float(count - 1) - 0.5;
	return eye_pos + eye_right * (offset * aperture_width);
}

float vision_origin_sees(vec2 point, int index, int count) {
	vec2 rel = point - vision_origin(index, count);
	float dist = length(rel);
	if (dist < 0.0001) {
		return 1.0;
	}

	float angle = vision_angle_to(rel / dist);
	if (abs(angle) > fan_half_angle) {
		return 0.0;
	}

	float u = (angle + fan_half_angle) / (2.0 * fan_half_angle);
	float v = (float(index) + 0.5) / float(count);
	vec2 traced = texture(vision_ranges, vec2(u, v)).rg;
	float fade = max(shadow_softness, 0.0001);
	float solid = 1.0 - smoothstep(traced.r, traced.r + fade, dist);
	float glass = 1.0 - smoothstep(traced.g, traced.g + fade, dist);

	return solid * (1.0 - window_shadow * (1.0 - glass));
}

float vision_visibility(vec2 uv) {
	vec2 point = vision_ground_point(uv);
	int count = textureSize(vision_ranges, 0).y;

	float unblocked = 0.0;
	for (int i = 0; i < count; i++) {
		unblocked += vision_origin_sees(point, i, count);
	}
	unblocked /= float(count);

	vec2 rel = point - eye_pos;
	float dist = length(rel);
	float angle = dist < 0.0001 ? 0.0 : vision_angle_to(rel / dist);

	float wedge = 1.0 - smoothstep(half_angle - edge_softness, half_angle, abs(angle));
	float in_range = 1.0 - smoothstep(view_distance - distance_fade, view_distance, dist);

	return wedge * unblocked * in_range;
}
