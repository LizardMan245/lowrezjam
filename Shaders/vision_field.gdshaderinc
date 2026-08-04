// Shared sampling code for every vision mode (normal, thermal, ...).
//
// The robot's field of view is baked every physics frame by Scripts/vision_field.gd
// into a 1D texture: for each angle across the camera cone, how far the robot can
// see before something blocks it. That makes the mask a real visibility polygon --
// walls throw shadows and corners hide what is behind them.
//
// Include this file and call vision_visibility(uv): 1.0 where the mounted camera
// can see, 0.0 where it cannot.

// How far the view reaches, per angle across the cone. R channel, world units.
uniform sampler2D vision_ranges : hint_default_white, filter_linear, repeat_disable;

uniform vec2 eye_pos = vec2(0.0);            // mounted camera position, world XZ
uniform vec2 eye_dir = vec2(0.0, 1.0);       // where it looks, world XZ, normalized
uniform float half_angle = 0.3926991;        // half the cone, radians
uniform float edge_softness = 0.0523599;     // feathering on the cone edges, radians
uniform float view_distance = 7.0;
uniform float distance_fade = 1.5;
uniform float shadow_softness = 0.25;        // how far a shadow edge fades into its occluder, world units
uniform float shadow_spread = 0.35;          // extra sideways penumbra per unit behind a corner

// Samples across the penumbra. Weighted, and enough of them that even the widest
// corner penumbra ramps smoothly instead of banding once per tap. Cheap here:
// the whole frame is 64x64.
const int SHADOW_TAPS = 32;

// Game camera, used to map a screen pixel back onto the ground plane.
// Assumes an orthographic camera (see Scripts/vision_field.gd).
uniform vec3 cam_pos = vec3(0.0, 10.0, 0.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 0.0, -1.0);
uniform vec3 cam_forward = vec3(0.0, -1.0, 0.0);
uniform vec2 cam_half_extents = vec2(5.0);
uniform float ground_height = 0.0;

// Screen pixel -> the point on the ground plane it looks at.
vec2 vision_ground_point(vec2 uv) {
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	vec3 origin = cam_pos
		+ cam_right * (ndc.x * cam_half_extents.x)
		+ cam_up * (ndc.y * cam_half_extents.y);
	float t = abs(cam_forward.y) < 0.0001 ? 0.0 : (ground_height - origin.y) / cam_forward.y;
	return (origin + cam_forward * t).xz;
}

// How far the view reaches at one angle off the centre line.
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

	// Signed angle off the cone's centre line.
	float angle = atan(
		eye_dir.y * to_pixel.x - eye_dir.x * to_pixel.y,
		dot(eye_dir, to_pixel));

	// The fade runs from the occluder into it: full brightness on the surface
	// being looked at, going dark as it carries on into the object. Driven by
	// shadow_softness alone -- letting shadow_spread widen it is what used to
	// wash out the dark behind a wall and make it see-through.
	float fade = max(shadow_softness, 0.0001);

	// What this pixel's own traced ray says: the sharp shadow. This is as far
	// forward as the mask is ever allowed to reach.
	float traced = vision_range_at(angle);
	float hard = 1.0 - smoothstep(traced, traced + fade, dist);

	// Sideways penumbra. Only a silhouette -- a corner, where neighbouring rays
	// reach very different distances -- has anything to average over, so this
	// widens corners without loosening a shadow's grip on the wall it comes off.
	float behind = max(dist - traced, 0.0);
	float window = min((fade + shadow_spread * behind) / max(dist, 0.001), 2.0 * half_angle);
	float step_angle = window / float(SHADOW_TAPS - 1);

	float soft = 0.0;
	float total_weight = 0.0;
	for (int i = 0; i < SHADOW_TAPS; i++) {
		float offset = float(i) - float(SHADOW_TAPS - 1) * 0.5;
		float weight = 1.0 - abs(offset) / (float(SHADOW_TAPS - 1) * 0.5 + 1.0);
		float limit = vision_range_at(angle + offset * step_angle);
		soft += weight * (1.0 - smoothstep(limit, limit + fade, dist));
		total_weight += weight;
	}
	soft /= total_weight;

	// Averaging a window is symmetric, which would drag darkness forward of the
	// sharp edge as well as back from it. Keeping whichever is brighter throws
	// the forward half away: softening only ever feathers a shadow backwards.
	float unblocked = max(soft, hard);

	float wedge = 1.0 - smoothstep(half_angle - edge_softness, half_angle, abs(angle));
	float in_range = 1.0 - smoothstep(view_distance - distance_fade, view_distance, dist);

	return wedge * unblocked * in_range;
}
