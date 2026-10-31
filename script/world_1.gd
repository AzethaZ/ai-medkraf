extends Node2D

@onready var fade_overlay: ColorRect = $FadeLayer/FadeOverlay

func _ready() -> void:
	if fade_overlay:
		# 1. Pastikan overlay hitam pekat saat scene baru dimuat
		fade_overlay.visible = true
		fade_overlay.modulate.a = 1.0
		
		# 2. Fade In: Layar perlahan kembali terang dalam 0.6 detik
		var tween = create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.6)
		await tween.finished
		
		# 3. Sembunyikan overlay setelah selesai agar tidak menghalangi interaksi
		fade_overlay.visible = false
