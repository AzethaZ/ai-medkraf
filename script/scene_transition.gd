extends CanvasLayer

var target_spawn_id: String = ""

@onready var color_rect: ColorRect = $ColorRect          # Fade biasa (ColorRect)
@onready var color_rect_2: ColorRect = $ColorRect2      # Shader Kedipan Cembung + Fade (ColorRect2)


func _ready() -> void:
	if color_rect:
		color_rect.visible = false
	if color_rect_2:
		color_rect_2.visible = false


# ==============================================================================
# --- FUNGSI UTAMA GANTI SCENE OTOMATIS (DI-PANGGIL OLEH AREA_EXIT) ---
# ==============================================================================
func change_scene(target_path: String) -> void:
	# 1. Kelopak mata cembung menutup dari atas-bawah + Layar meredup (0.65 detik)
	await smooth_blink_out(0.65)
	
	# 2. TAHAN LAYAR GELAP: Jeda diam saat mata tertutup rapat (0.35 detik)
	await get_tree().create_timer(0.35).timeout
	
	# 3. Pindah Scene
	get_tree().change_scene_to_file(target_path)
	
	# 4. Tunggu 1 frame agar scene baru selesai di-render
	await get_tree().process_frame
	
	# 5. Kelopak mata cembung mekar terbuka + Layar menerang kembali (0.65 detik)
	smooth_blink_in(0.65)


# ==============================================================================
# --- 1. TRANSISI KEDIPAN MATA CEMBUNG + FADE (COLORRECT2 + SHADER) ---
# ==============================================================================

func smooth_blink_out(duration: float = 0.65) -> void:
	if not color_rect_2:
		return
	color_rect_2.visible = true
	
	var mat = color_rect_2.material as ShaderMaterial
	if mat:
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/progress", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished


func smooth_blink_in(duration: float = 0.65) -> void:
	if not color_rect_2:
		return
	color_rect_2.visible = true
	
	var mat = color_rect_2.material as ShaderMaterial
	if mat:
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/progress", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		
	color_rect_2.visible = false


# ==============================================================================
# --- 2. TRANSISI FADE BIASA / CADANGAN (COLORRECT UTAMA) ---
# ==============================================================================

func fade_out(duration: float = 0.5) -> void:
	if not color_rect:
		return
	color_rect.visible = true
	color_rect.modulate.a = 0.0
	var tween = create_tween()
	await tween.tween_property(color_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).finished


func fade_in(duration: float = 0.5) -> void:
	if not color_rect:
		return
	color_rect.visible = true
	color_rect.modulate.a = 1.0
	var tween = create_tween()
	await tween.tween_property(color_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).finished
	color_rect.visible = false
