# scene_transition.gd (atau script SceneTransition kamu)
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect # Sesuaikan nama node ColorRect hitam kamu

# Animasi Layar Menjadi Hitam (Fade Out)
func fade_out(duration: float = 0.5) -> void:
	color_rect.visible = true
	var tween = create_tween()
	await tween.tween_property(color_rect, "modulate:a", 1.0, duration).finished

# Animasi Layar Terang Kembali (Fade In)
func fade_in(duration: float = 0.5) -> void:
	var tween = create_tween()
	await tween.tween_property(color_rect, "modulate:a", 0.0, duration).finished
	color_rect.visible = false
