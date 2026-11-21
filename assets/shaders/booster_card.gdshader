shader_type canvas_item;
render_mode unshaded;

// Карточка-билет бустера в магазине: тёплая бумага с зерном и виньеткой,
// боковые вырезы-перфорация на линии отрыва, пунктир под шапкой,
// тиснёная рамка и ценовой акцент. Центр не перекрывает содержимое.

uniform vec2 rect_size = vec2(130.0, 112.0);
uniform float radius = 10.0;
uniform vec4 top_color : source_color = vec4(0.941, 0.835, 0.678, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.847, 0.714, 0.541, 1.0);
uniform vec4 border_color : source_color = vec4(0.568627, 0.27451, 1.0, 0.45);
uniform vec4 accent_color : source_color = vec4(0.804, 0.498, 0.196, 1.0);
uniform vec4 line_color : source_color = vec4(0.168627, 0.0588235, 0.290196, 1.0);
uniform float border_width = 1.0;
// Высота шапки: на этой линии с боков вырезаны полукруглые выемки.
uniform float perforation_y = 25.5;
uniform float notch_radius = 5.0;
uniform float grain_strength = 0.022;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 half_size = rect_size * 0.5;

	// Форма билета: скруглённый прямоугольник с двумя вырезами по бокам.
	float d = sd_round_box(p, half_size, radius);
	float line_y = perforation_y - rect_size.y * 0.5;
	float notch_a = length(p - vec2(-half_size.x, line_y)) - notch_radius;
	float notch_b = length(p - vec2(half_size.x, line_y)) - notch_radius;
	float notch = min(notch_a, notch_b);
	d = max(d, -notch);

	float aa = max(fwidth(d), 0.6);
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float depth = -d;

	// Бумага: вертикальный градиент, зерно и лёгкое затемнение к краям.
	vec3 fill = mix(top_color.rgb, bottom_color.rgb, UV.y);
	float grain = hash21(floor(UV * rect_size)) - 0.5;
	fill += grain * grain_strength;
	vec2 v = (UV - 0.5) * vec2(1.0, 0.82);
	fill *= 1.0 - dot(v, v) * 0.26;

	vec3 col = fill;

	// Пунктир линии отрыва: частые короткие штрихи под шапкой.
	float line_band = 1.0 - smoothstep(0.55, 1.25, abs(p.y - line_y));
	float dots = step(0.42, fract(p.x / 5.5));
	col = mix(col, line_color.rgb, line_band * dots * 0.42);

	// Тиснёная рамка по всему контуру, включая дуги вырезов.
	float border = 1.0 - smoothstep(border_width - aa, border_width + aa, depth);
	col = mix(col, border_color.rgb, border_color.a * border);

	// Светлая внутренняя линия — край бумаги будто приподнят.
	float emboss = smoothstep(border_width + 0.3, border_width + 1.1, depth)
		* (1.0 - smoothstep(border_width + 1.3, border_width + 2.1, depth));
	vec3 emboss_color = mix(vec3(1.0, 0.965, 0.88), accent_color.rgb, 0.35);
	col = mix(col, emboss_color, emboss * 0.34);

	COLOR = vec4(col, inside);
}
