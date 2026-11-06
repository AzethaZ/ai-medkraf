shader_type canvas_item;
render_mode blend_add;

uniform vec4 ray_color : source_color = vec4(1.0, 0.95, 0.7, 0.25);
uniform float position : hint_range(-1.0, 1.0) = 0.0;
uniform float falloff : hint_range(0.0, 2.0) = 1.2;
uniform float speed : hint_range(0.0, 10.0) = 0.8;

// EFEK PIXEL: Semakin kecil nilainya, semakin besar/kotak-kotak pikselnya
uniform float pixel_size : hint_range(32.0, 512.0) = 200;

float ray_noise(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// 1. UBAH KOORDINAT MENJADI PIXELATED (KOTAK-KOTAK)
	vec2 pixel_uv = floor(UV * pixel_size) / pixel_size;
	float time = TIME * speed;
	
	// 2. Kalkulasi sinar lurus tegak menggunakan pixel_uv
	vec2 ray_uv = pixel_uv;
	ray_uv.x += position;
	
	// 3. Pola denyut berkas sinar vertikal pixelated
	float rays = sin(ray_uv.x * 35.0 + time) * 0.5 + 0.5;
	rays += sin(ray_uv.x * 60.0 - time * 0.7) * 0.25;
	
	// 4. Fade dari atas ke bawah
	float vertical_fade = smoothstep(0.0, falloff, pixel_uv.y);
	
	COLOR = ray_color * rays * (1.0 - vertical_fade);
}