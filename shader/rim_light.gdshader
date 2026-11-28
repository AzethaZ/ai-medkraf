shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.5, 0.9);
uniform float rim_thickness : hint_range(0.0, 5.0) = 1.0;
uniform vec2 light_direction = vec2(1.0, -1.0);
uniform float rim_intensity : hint_range(0.0, 5.0) = 1.5;

// Animasi naik-turun cahaya
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.5;
uniform float min_opacity : hint_range(0.0, 1.0) = 0.2;
uniform float max_opacity : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	// Ambil warna tekstur asli (jangan dikali vertex_modulate lagi agar tidak double gelap)
	vec4 tex = texture(TEXTURE, UV);
	
	if (tex.a > 0.0) {
		vec2 size = TEXTURE_PIXEL_SIZE * rim_thickness;
		vec2 offset = normalize(light_direction) * size;
		
		// Cek pixel tetangga di arah kanan atas (UV + offset)
		float neighbor_alpha = texture(TEXTURE, UV + offset).a;
		
		if (neighbor_alpha < 0.1) {
			float wave = (sin(TIME * pulse_speed) + 1.0) * 0.5;
			float dynamic_alpha = mix(min_opacity, max_opacity, wave) * rim_color.a;
			
			// Tambahkan kilau cahaya di atas warna tekstur asli
			vec3 final_rgb = tex.rgb + (rim_color.rgb * rim_intensity * dynamic_alpha);
			COLOR = vec4(final_rgb, tex.a);
		} else {
			COLOR = tex;
		}
	} else {
		COLOR = tex;
	}
}