shader_type canvas_item;

// 0.0 = Terbuka & Terang, 1.0 = Tertutup Rapat & Hitam Penuh
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Kekuatan lengkungan cembung (menonjol ke arah garis tengah)
uniform float curve_intensity : hint_range(0.0, 0.5) = 0.15;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    // 1. Jarak murni sumbu Y dari GARIS TENGAH LAYAR (Y = 0.5)
    float dist_from_center = abs(UV.y - 0.5);
    
    // 2. Lengkungan Cembung: bagian tengah (UV.x = 0.5) menonjol melengkung merapat ke tengah
    float curve = sin(UV.x * 3.14159) * curve_intensity * (1.0 - progress);
    
    // 3. Ditambahkan (+ curve) agar bagian tengah menutup DULUAN dibanding pinggirnya
    float eyelid_boundary = ((1.0 - progress) * 0.5) + curve;
    
    // 4. Kombinasi Kedip Cembung + Fade:
    if (dist_from_center >= eyelid_boundary) {
        COLOR = transition_color;
    } else {
        COLOR = vec4(transition_color.rgb, progress);
    }
}