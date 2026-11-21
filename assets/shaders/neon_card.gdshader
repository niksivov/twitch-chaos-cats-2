shader_type canvas_item;
render_mode unshaded;

// Неоновая стеклянная карточка с анимированной рамкой и глоу.
uniform vec2 rect_size = vec2(700.0, 420.0);
uniform float inset = 44.0;
uniform float radius = 26.0;
uniform vec4 fill_top : source_color = vec4(0.070, 0.035, 0.135, 0.90);
uniform vec4 fill_bottom : source_color = vec4(0.030, 0.015, 0.065, 0.94);
uniform vec4 neon_a : source_color = vec4(0.45, 0.18, 1.0, 1.0);
uniform vec4 neon_b : source_color = vec4(1.0, 0.25, 0.82, 1.0);
uniform float inner_line_offset = 14.0;
uniform float inner_line_strength = 0.17;
uniform vec4 orb_color : source_color = vec4(0.35, 0.2, 0.7, 1.0);
uniform vec4 sweep_color : source_color = vec4(0.25, 0.12, 0.45, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 uv = UV * rect_size;
	vec2 center = rect_size * 0.5;
	vec2 half_size = (rect_size - vec2(inset * 2.0)) * 0.5;
	float d = sd_round_box(uv - center, half_size, radius);

	float inside = smoothstep(0.8, -0.8, d);
	float outside = 1.0 - inside;

	// Тёмное стекло с лёгким шумом.
	vec3 fill = mix(fill_top.rgb, fill_bottom.rgb, UV.y);
	fill += vec3(0.030, 0.015, 0.060) * smoothstep(0.72, 0.0, UV.y);
	fill += (hash21(floor(uv * 0.8)) - 0.5) * 0.012;
	fill += vec3(0.008) * sin(uv.y * 24.0);

	// Переливающаяся фиолетово-розовая рамка.
	float g = clamp(0.5 + 0.5 * sin(uv.x / rect_size.x * 3.4 + uv.y / rect_size.y * 1.7 + TIME * 0.45), 0.0, 1.0);
	vec3 neon = mix(neon_a.rgb, neon_b.rgb, g);

	float border = 1.0 - smoothstep(1.0, 2.4, abs(d));
	float outer_glow = exp(-max(d, 0.0) * 0.09) * 0.70 * outside;
	float inner_glow = exp(-max(-d, 0.0) * 0.12) * 0.16;
	float inner_line = (1.0 - smoothstep(0.7, 1.5, abs(d + inner_line_offset))) * inner_line_strength * inside;

	// Цветные блики внутри карточки.
	float orb1 = exp(-length(uv - vec2(rect_size.x * 0.18, rect_size.y * 0.24)) * 0.012) * 0.14;
	float orb2 = exp(-length(uv - vec2(rect_size.x * 0.84, rect_size.y * 0.80)) * 0.014) * 0.10;

	// Мелкие мерцающие точки вместо крупных квадратов.
	vec2 cell = floor(uv / 16.0);
	float rnd = hash21(cell);
	vec2 jitter = vec2(hash21(cell + 3.7), hash21(cell + 9.1));
	vec2 star_pos = (cell + 0.25 + jitter * 0.5) * 16.0;
	float star_dist = length(uv - star_pos);
	float star = step(0.94, rnd) * smoothstep(1.8, 0.0, star_dist);
	star *= (0.5 + 0.5 * sin(TIME * 2.2 + rnd * 6.2832)) * 0.8 * inside;

	// Медленный блик по диагонали.
	float coord = (uv.x + uv.y * 0.55) / (rect_size.x + rect_size.y * 0.55);
	float sweep = fract(TIME * 0.07);
	float pulse = smoothstep(0.11, 0.0, abs(coord - sweep));
	fill += sweep_color.rgb * pulse * 0.05;

	vec3 rgb = fill * inside;
	rgb += neon * (border * 1.35 + outer_glow * 1.6 + inner_glow + inner_line);
	rgb += orb_color.rgb * (orb1 + orb2) * inside;
	rgb += neon * star;

	float fill_alpha = mix(fill_top.a, fill_bottom.a, UV.y);
	float alpha = clamp(fill_alpha * inside + outer_glow, 0.0, 1.0);
	COLOR = vec4(rgb, alpha);
}
