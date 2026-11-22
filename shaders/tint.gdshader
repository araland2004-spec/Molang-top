shader_type spatial;
// 집 지붕·벽 색 바꾸기: 원래 텍스처의 밝기 무늬는 살리고 색만 바꿔요.
uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 tint : source_color = vec3(1.0);
uniform float amt = 1.0;
void fragment() {
	vec4 c = texture(tex, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(c.rgb, tint * (0.35 + l * 1.1), amt);
}
