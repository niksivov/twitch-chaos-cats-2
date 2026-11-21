shader_type canvas_item;

// Скругляет аватар по форме карточки, чтобы углы не выходили за неоновую рамку.

uniform vec2 rect_size = vec2(113.0, 108.0);
uniform float radius = 8.0;
// 0 — исходный цвет, 1 — чёрно-белый аватар.
uniform float grayscale : hint_range(0.0, 1.0) = 0.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	float d = sd_round_box(p, rect_size * 0.5, radius);
	COLOR = texture(TEXTURE, UV);
	float gray = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(gray), grayscale);
	COLOR.a *= clamp(0.5 - d, 0.0, 1.0);
}
