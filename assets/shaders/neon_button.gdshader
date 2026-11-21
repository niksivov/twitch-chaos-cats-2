shader_type canvas_item;
render_mode unshaded;

// Неоновая кнопка: градиент, глянец, глоу и hover-блик.
uniform vec2 rect_size = vec2(564.0, 82.0);
uniform float inset = 12.0;
uniform float radius = 14.0;
uniform vec4 color_a : source_color = vec4(0.36, 0.10, 0.90, 1.0);
uniform vec4 color_b : source_color = vec4(0.72, 0.12, 0.72, 1.0);
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform float press : hint_range(0.0, 1.0) = 0.0;

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

	float g = clamp(0.5 + 0.5 * sin(uv.x / rect_size.x * 2.2 + TIME * 0.8), 0.0, 1.0);
	vec3 col = mix(color_a.rgb, color_b.rgb, g) * mix(1.0, 0.82, UV.y);
	col = mix(col, vec3(1.0, 0.82, 1.0), hover * 0.16);
	col *= 1.0 - press * 0.18;

	// Глянцевая верхняя полоса и затемнение низа.
	float gloss = smoothstep(0.50, 0.05, UV.y) * 0.26 * inside;
	float shade = smoothstep(0.55, 1.0, UV.y) * 0.22 * inside;

	float border = 1.0 - smoothstep(1.0, 2.6, abs(d));
	float glow = exp(-max(d, 0.0) * 0.14) * (0.50 + 0.40 * hover);

	// Бегущий блик при наведении.
	float next_x = fract((uv.x / rect_size.x) - TIME * 0.28 + 0.5);
	float hover_shine = smoothstep(0.12, 0.0, abs(next_x - 0.5)) * 0.18 * hover * inside;

	vec3 rgb = col * inside;
	rgb += vec3(1.0) * gloss;
	rgb += vec3(1.0, 0.85, 1.0) * hover_shine;
	rgb *= 1.0 - shade;
	rgb += mix(color_a.rgb, color_b.rgb, 0.5) * border * 0.8;
	rgb += col * glow;
	float alpha = clamp(inside + glow * 0.7 * (1.0 - inside), 0.0, 1.0);
	COLOR = vec4(rgb, alpha);
}
