shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.85, 0.92, 1.0, 0.35);
uniform float density : hint_range(0.0, 2.0) = 0.85;
uniform vec2 wind_speed = vec2(0.04, 0.005); // Kecepatan gerak embun (X = samping, Y = vertikal)
uniform float fade_speed : hint_range(0.0, 5.0) = 0.7; // Kecepatan timbul-tenggelam (fade slow)
uniform float fog_scale : hint_range(1.0, 15.0) = 4.5; // Ukuran gumpalan kabut
uniform float top_fade : hint_range(0.0, 1.0) = 0.35; // Gradasi pudar di sisi atas
uniform float bottom_fade : hint_range(0.0, 1.0) = 0.2; // Gradasi pudar di sisi bawah
uniform float pixel_size : hint_range(32.0, 512.0) = 180.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Fractal Brownian Motion (FBM) 3 lapis untuk tekstur embun lembut
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.05;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// 1. Pixelate koordinat UV
	vec2 pixel_uv = floor(UV * pixel_size) / pixel_size;

	// 2. Pergerakan kabut dua arah yang lembut
	vec2 uv1 = pixel_uv * fog_scale + TIME * wind_speed;
	vec2 uv2 = pixel_uv * (fog_scale * 1.6) - TIME * (wind_speed * 0.6);
	float mist = (fbm(uv1) + fbm(uv2)) * 0.5;

	// 3. Efek fade slow (embun menebal & memudar perlahan)
	float slow_pulse = sin(TIME * fade_speed + pixel_uv.x * 2.0) * 0.25 + 0.75;

	// 4. Pudarkan tepi atas & bawah agar menyatu halus dengan background
	float edge_top = smoothstep(0.0, max(top_fade, 0.01), pixel_uv.y);
	float edge_bottom = 1.0 - smoothstep(1.0 - max(bottom_fade, 0.01), 1.0, pixel_uv.y);

	float alpha = smoothstep(0.25, 0.85, mist) * density * slow_pulse * edge_top * edge_bottom;
	COLOR = vec4(fog_color.rgb, clamp(fog_color.a * alpha, 0.0, 1.0));
}