shader_type canvas_item;

// Анимированная рамка активного игрока в стиле «Змеиная чешуя».
// Рисует только кольцо рамки: короткие сегменты-чешуйки медленно
// перетекают по периметру, чередуя тёмно-зелёный и ядовито-зелёный.
// Центр карточки прозрачный, поэтому фон и содержимое не затрагиваются.

// Размер контрола в пикселях.
uniform vec2 rect_size = vec2(128.0, 128.0);
// Прозрачный отступ от края контрола до внешней границы рамки (место свечения).
uniform float inset = 4.0;
// Толщина кольца рамки.
uniform float border_width = 3.0;
uniform float corner_radius = 10.0;
// Количество чешуек по периметру и скорость их бега (пикселей в секунду).
uniform float segments = 32.0;
uniform float flow_speed = 18.0;
uniform vec4 color_dark : source_color = vec4(0.015, 0.075, 0.025, 1.0);
uniform vec4 color_mid : source_color = vec4(0.07, 0.38, 0.06, 1.0);
uniform vec4 color_bright : source_color = vec4(0.5, 1.0, 0.0, 1.0);
uniform float glow_strength = 0.5;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453123);
}

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 half_size = max(rect_size * 0.5 - vec2(inset), vec2(1.0));
	float radius = min(corner_radius, min(half_size.x, half_size.y));
	float d = sd_round_box(p, half_size, radius);
	float depth = -d;

	// Кольцо рамки с мягкими краями.
	float aa = max(fwidth(d), 0.75);
	float outer = smoothstep(aa, -aa, d);
	float inner = 1.0 - smoothstep(border_width - aa, border_width + aa, depth);
	float ring = outer * inner;

	// Координата вдоль кольца: угол вокруг центра даёт плавный бег
	// без разрывов на углах карточки. Число чешуек целое, поэтому
	// стык в левой точке периметра незаметен.
	float total = 4.0 * (half_size.x + half_size.y);
	float u = (atan(p.y, p.x) / 6.2831853 + 0.5) * total;
	float flow = (u - TIME * flow_speed) / total * segments;
	float t = fract(flow);
	float cell = floor(flow);

	// Основа — непрерывная тёмно-зелёная «кожа» с медленными пятнами,
	// чтобы между чешуйками не было ощущения пунктира.
	float patch_wave = sin(u * 0.052 - TIME * flow_speed * 0.02)
		+ 0.6 * sin(u * 0.021 + TIME * 0.45 + 1.7)
		+ 0.35 * sin(u * 0.13 - TIME * 0.8 + 4.1);
	float patch = clamp(0.5 + 0.28 * patch_wave, 0.0, 1.0);
	vec3 col = mix(color_dark.rgb, color_mid.rgb, 0.2 + 0.55 * patch);

	// Каждая чешуйка имеет свой размер, тон и мягкий гребень.
	float rnd = hash11(cell + 0.37);
	float rnd_b = hash11(cell + 11.9);
	float start = 0.02 + 0.04 * rnd;
	float end = 0.84 + 0.1 * rnd_b;
	float tone = mix(0.42, 1.0, smoothstep(0.2, 0.82, hash11(cell + 5.3)));

	// Поперёк рамки чешуйка выпуклая: края темнее, середина светлее.
	float across = clamp(depth / max(border_width, 0.001), 0.0, 1.0);
	float dome = sin(across * PI);

	// Лёгкий изгиб краёв чешуек поперёк рамки — эффект наложения.
	float tc = fract(t + (across - 0.5) * 0.12);
	float body = smoothstep(start, start + 0.13, tc) * (1.0 - smoothstep(end - 0.16, end, tc));

	float light = body * (0.45 + 0.55 * dome) * tone;
	col = mix(col, color_mid.rgb, light);
	col = mix(col, color_bright.rgb, smoothstep(0.45, 0.95, light) * (0.7 + 0.3 * dome));

	// Тусклый второй ряд со сдвигом на полчешуйки — намёк на наложение.
	float t2 = fract(flow + 0.5);
	float body2 = smoothstep(0.08, 0.28, t2) * (1.0 - smoothstep(0.62, 0.86, t2));
	float light2 = body2 * dome * mix(0.25, 0.6, hash11(cell + 17.0));
	col = mix(col, color_mid.rgb, light2);

	// Блик на гребне отдельных чешуек.
	float sheen = pow(dome, 2.0)
		* smoothstep(0.24, 0.38, t) * (1.0 - smoothstep(0.38, 0.56, t))
		* step(0.62, rnd);
	col += vec3(0.28, 0.46, 0.16) * sheen * 0.7;

	// Лёгкое внешнее свечение вокруг рамки.
	float glow = smoothstep(-1.0, 0.5, d) * exp(-max(d, 0.0) / 2.2) * glow_strength;

	float alpha = clamp(ring + glow * (1.0 - ring), 0.0, 1.0);
	vec3 rgb = (col * ring + color_bright.rgb * glow * (1.0 - ring)) / max(alpha, 0.0001);

	// Едва заметное дыхание яркости.
	rgb *= 0.95 + 0.05 * sin(TIME * 1.8);
	COLOR = vec4(rgb, alpha);
}
