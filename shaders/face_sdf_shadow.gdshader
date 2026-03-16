shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mul;

uniform sampler2D sdf_texture : hint_default_white;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.55, 0.72, 1.0);
uniform float feather : hint_range(0.0, 0.1) = 0.02;
// x = right_dot (양수=빛이 오른쪽, 음수=빛이 왼쪽)
// y = theta (0=빛이 정면→그림자 없음, 1=빛이 뒤→완전 그림자)
uniform vec2 light_dir_xz = vec2(0.0, 0.0);
uniform float debug_sdf : hint_range(0.0, 1.0, 1.0) = 0.0;

void fragment() {
	float right_dot = light_dir_xz.x;
	float theta = light_dir_xz.y;

	// 빛이 왼쪽이면 UV 미러
	vec2 sdf_uv = UV;
	if (right_dot < 0.0) {
		sdf_uv.x = 1.0 - UV.x;
	}

	float sdf_val = texture(sdf_texture, sdf_uv).r;

	if (debug_sdf > 0.5) {
		// theta 기준 경계선 (빛 방향 따라 움직임)
		float contour = 1.0 - smoothstep(0.0, 0.015, abs(sdf_val - theta));
		ALBEDO = mix(vec3(sdf_val), vec3(1.0, 0.0, 0.0), contour);
		ALPHA = 0.85;
	} else {
		// theta > sdf_val → 빛이 이 픽셀의 임계값을 넘어섬 → 그림자
		float shadow = smoothstep(sdf_val - feather, sdf_val + feather, theta);
		// blend_mul: dst * ALBEDO
		// shadow=0 → ALBEDO=(1,1,1) → 변화 없음
		// shadow=1 → ALBEDO=shadow_tint → 피부색이 그림자 색으로 곱해짐
		// 검정 눈썹은 (0,0,0) * shadow_tint = 그대로 검정
		ALBEDO = mix(vec3(1.0), shadow_tint.rgb, shadow);
		ALPHA = 1.0;
	}
}
