shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.1, 0.45);
uniform float radius : hint_range(0.05, 1.0) = 0.45;
uniform float softness : hint_range(0.05, 1.0) = 0.35;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.12;
uniform float pixel_size : hint_range(16.0, 256.0) = 64.0;

void fragment() {
	// 1. Pixelate koordinat UV agar sesuai estetika pixel art
	vec2 pixel_uv = floor(UV * pixel_size) / pixel_size;

	// 2. Denyut kedap-kedip alami api (gabungan 2 gelombang sinus)
	float flicker = sin(TIME * flicker_speed) * 0.6 + sin(TIME * flicker_speed * 2.3 + 1.5) * 0.4;
	float dynamic_radius = radius + (flicker * flicker_amount * 0.35);
	float dynamic_alpha = 1.0 + (flicker * flicker_amount);

	// 3. Hitung jarak radial dari titik tengah ColorRect (0.5, 0.5)
	float dist = distance(pixel_uv, vec2(0.5));
	float radial_mask = 1.0 - smoothstep(max(0.0, dynamic_radius - softness), dynamic_radius, dist);

	COLOR = vec4(glow_color.rgb, glow_color.a * radial_mask * dynamic_alpha);
}