shader_type canvas_item;

uniform float radius : hint_range(0.0, 2.0) = 0.0;
uniform float softness : hint_range(0.0, 0.3) = 0.08; // 경계 흐릿함 정도

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	// 화면 비율 보정 (찌그러짐 방지)
	vec2 uv = UV - center;
	uv.x *= 1.777; // 16:9 비율
	float dist = length(uv);

	// step() 대신 smoothstep() — 경계가 부드럽게 페이드
	float alpha = smoothstep(radius - softness, radius + softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}