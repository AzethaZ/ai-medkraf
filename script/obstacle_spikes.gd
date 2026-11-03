extends Node2D

@export var move_speed: float = 200.0  # Samakan dengan scroll_speed Parallax kamu

func _process(delta: float) -> void:
	# Gerakkan duri ke arah kiri secara kontinyu
	position.x -= move_speed * delta
	
	# Hapus otomatis dari memory jika sudah lewat jauh di luar layar kiri
	if position.x < -400:
		queue_free()
