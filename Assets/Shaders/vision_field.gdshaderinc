uniform sampler2D vision_ranges : hint_default_white, filter_linear, repeat_disable;

uniform vec2 eye_pos = vec2(0.0);
uniform vec2 eye_dir = vec2(0.0, 1.0);
uniform float half_angle = 0.3926991;
uniform float edge_softness = 0.0523599;
uniform float view_distance = 7.0;
uniform float distance_fade = 1.5;
uniform float shadow_softness = 0.25;
uniform float silhouette_angle = 0.10472;

const int SHADOW_TAPS = 32;

uniform vec3 cam_pos = vec3(0.0, 10.0, 0.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 0.0, -1.0);
uniform vec3 cam_forward = vec3(0.0, -1.0, 0.0);
uniform vec2 cam_half_extents = vec2(5.0);
uniform float ground_height = 0.0;

vec2 vision_ground_point(vec2 uv) {
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	vec3 origin = cam_pos
		+ cam_right * (ndc.x * cam_half_extents.x)
		+ cam_up * (ndc.y * cam_half_extents.y);
	float t = abs(cam_forward.y) < 0.0001 ? 0.0 : (ground_height - origin.y) / cam_forward.y;
	return (origin + cam_forward * t).xz;
}

float vision_range_at(float angle) {
	float u = (angle + half_angle) / (2.0 * half_angle);
	return texture(vision_ranges, vec2(clamp(u, 0.0, 1.0), 0.5)).r;
}

float vision_visibility(vec2 uv) {
	vec2 rel = vision_ground_point(uv) - eye_pos;
	float dist = length(rel);
	if (dist < 0.0001) {
		return 1.0;
	}
	vec2 to_pixel = rel / dist;

	float angle = atan(
		eye_dir.y * to_pixel.x - eye_dir.x * to_pixel.y,
		dot(eye_dir, to_pixel));

	float fade = max(shadow_softness, 0.0001);
	float span = min(silhouette_angle, 2.0 * half_angle);
	float step_angle = span / float(SHADOW_TAPS);

	float unblocked = 0.0;
	for (int i = 0; i <= SHADOW_TAPS; i++) {
		float offset = step_angle * float(i);
		float angular = 1.0 - smoothstep(0.0, span, offset);
		float plus = vision_range_at(angle + offset);
		float minus = vision_range_at(angle - offset);
		float lit = max(
			1.0 - smoothstep(plus, plus + fade, dist),
			1.0 - smoothstep(minus, minus + fade, dist));
		unblocked = max(unblocked, angular * lit);
	}

	float wedge = 1.0 - smoothstep(half_angle - edge_softness, half_angle, abs(angle));
	float in_range = 1.0 - smoothstep(view_distance - distance_fade, view_distance, dist);

	return wedge * unblocked * in_range;
}
