extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

func _ready() -> void:
	# 1. Matikan kontrol player sejenak saat layar masih hitam
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# 2. Aktifkan kamera di scene ini
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()

	# 3. Buka layar hitam secara perlahan (Fade In)
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 4. Kembalikan kontrol player setelah layar terbuka sempurna
	if player and player.has_method("enable_movement"):
		player.enable_movement()
