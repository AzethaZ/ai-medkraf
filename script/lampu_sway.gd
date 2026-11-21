extends Sprite2D

@export var sway_x: float = 4.0            # Jarak ayun kanan-kiri (piksel)
@export var sway_y: float = 0.6            # Sedikit lengkungan bawah (sangat kecil agar tidak naik-turun jauh)
@export var sway_angle_deg: float = 0.35   # Rotasi sangat tipis agar ujung kiri-kanan layer tidak terangkat ke atas
@export var sway_duration: float = 2.4     # Durasi satu ayunan angin (detik)

func _ready() -> void:
	var base_pos := position
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# 1. Ayun ke kanan (sedikit turun mengikuti lengkungan tali)
	tween.tween_property(self, "position", base_pos + Vector2(sway_x, sway_y), sway_duration * 0.5)
	tween.parallel().tween_property(self, "rotation_degrees", sway_angle_deg, sway_duration * 0.5)

	# 2. Kembali ke titik tengah (paling rendah)
	tween.tween_property(self, "position", base_pos, sway_duration * 0.5)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, sway_duration * 0.5)

	# 3. Ayun ke kiri
	tween.tween_property(self, "position", base_pos + Vector2(-sway_x, sway_y), sway_duration * 0.5)
	tween.parallel().tween_property(self, "rotation_degrees", -sway_angle_deg, sway_duration * 0.5)

	# 4. Kembali ke titik tengah
	tween.tween_property(self, "position", base_pos, sway_duration * 0.5)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, sway_duration * 0.5)
