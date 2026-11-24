// 픽셀아트 렌더: 3D 화면을 큰 픽셀(px 화면 픽셀 = 1칸)로 찍고, 깊이가 끊기는 곳(물체 외곽)에 검은 아웃라인.
// 카메라 앞 화면 전체를 덮는 판에 씌워요 (main._setup_pixel_art). UI는 영향 없음.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float px = 4.0;                  // 큰 픽셀 하나 = 화면 픽셀 몇 개
uniform vec4 line_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_rel = 0.03;           // 깊이 차이가 이 비율보다 크면 외곽선
uniform float line_abs = 0.08;
uniform float on = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

float lin(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	if (d >= 0.99999) {
		return 100000.0;          // 하늘(아무것도 없음): 아주 멀리 → 섬 테두리에도 선이 생겨요
	}
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 vs = VIEWPORT_SIZE;
	vec2 cell = floor(SCREEN_UV * vs / px);
	vec2 c = (cell + 0.5) * px / vs;
	vec2 o = vec2(px) / vs;
	vec3 col = texture(screen_tex, c).rgb;
	float d0 = lin(c, INV_PROJECTION_MATRIX);
	float dn = min(min(lin(c + vec2(o.x, 0.0), INV_PROJECTION_MATRIX), lin(c - vec2(o.x, 0.0), INV_PROJECTION_MATRIX)),
		min(lin(c + vec2(0.0, o.y), INV_PROJECTION_MATRIX), lin(c - vec2(0.0, o.y), INV_PROJECTION_MATRIX)));
	// 이 칸이 뒤쪽이고 옆 칸이 확 가까우면 = 앞 물체의 바깥 테두리 → 검은 선
	float edge = step(max(line_abs, d0 * line_rel), d0 - dn);
	col = mix(col, line_col.rgb, edge * line_col.a);
	ALBEDO = mix(texture(screen_tex, SCREEN_UV).rgb, col, on);
}
