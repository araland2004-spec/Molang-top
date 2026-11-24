shader_type spatial;
// 오너먼트 닦기 (올데이 인 크리스마스와 같은 방식)
// mask: 모델 가운데에서 본 방향(위도·경도) 지도. 1 = 더러움, 0 = 깨끗.  0.59~1 겉먼지, 0~0.59 묵은 때
uniform sampler2D mask : filter_linear, repeat_enable;
uniform vec3 col_a : source_color = vec3(0.8, 0.15, 0.2);
uniform vec3 col_b : source_color = vec3(1.0, 0.85, 0.4);
uniform int pattern = 0;          // 0 띠 · 1 줄무늬 · 2 물방울 · 3 눈꽃 지그재그
uniform float shine = 1.0;        // 다 닦으면 반짝

varying vec3 ldir;

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() { ldir = normalize(VERTEX); }

void fragment() {
	vec3 d = normalize(ldir);
	float lat = asin(clamp(d.y, -1.0, 1.0));
	float lon = atan(d.z, d.x);
	vec2 uv = vec2(lon / 6.2831853 + 0.5, lat / 3.14159265 + 0.5);
	// 무늬
	vec3 base = col_a;
	if (pattern == 0) {
		base = mix(col_a, col_b, step(abs(d.y), 0.12));
	} else if (pattern == 1) {
		base = mix(col_a, col_b, step(0.5, fract(lon * 12.0 / 6.2831853 + d.y * 1.5)));
	} else if (pattern == 2) {
		vec2 g = fract(vec2(lon * 8.0 / 6.2831853, lat * 4.0 / 3.14159265)) - 0.5;
		base = mix(col_a, col_b, step(length(g), 0.22));
	} else {
		float z = abs(fract(lon * 10.0 / 6.2831853) - 0.5) * 0.5;
		base = mix(col_a, col_b, step(abs(d.y - z + 0.12), 0.06));
	}
	float m = texture(mask, uv).r;
	float g = n3(d * 9.0);
	float g2 = n3(d * 23.0);
	float dust = smoothstep(0.6, 0.74, m + (g - 0.5) * 0.16);
	float grm = smoothstep(0.03, 0.26, m + (g - 0.5) * 0.18 * step(0.01, m));
	vec3 old = base * 0.45 + vec3(0.12, 0.1, 0.07);
	vec3 dustc = mix(vec3(0.64, 0.58, 0.47), vec3(0.49, 0.43, 0.34), g2);
	dustc *= 1.0 - step(0.82, n3(d * 47.0)) * 0.35;
	vec3 c = mix(base, mix(base * 0.5, old, 0.78), grm * 0.95);
	c = mix(c, dustc, dust * 0.96);
	float dirt = max(dust, grm * 0.85);
	ALBEDO = c;
	METALLIC = mix(0.55, 0.0, dirt);
	ROUGHNESS = mix(0.18, 0.95, dirt);
	SPECULAR = mix(0.8, 0.2, dirt);
	EMISSION = base * 0.25 * shine * (1.0 - dirt);
}
