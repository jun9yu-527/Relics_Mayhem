shader_type canvas_item;

uniform float radius : hint_range(0.0, 2.0) = 0.0;
uniform float softness : hint_range(0.0, 0.3) = 0.08; // 원의 경계 부분의 흐림도 조절

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	// 화면 비율 보정
	vec2 uv = UV - center;
	uv.x *= 1.777; // 16:9 비율
	float dist = length(uv);

	// step() 대신 smoothstep() — 경계가 부드럽게 페이드인 아웃
	float alpha = smoothstep(radius - softness, radius + softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}