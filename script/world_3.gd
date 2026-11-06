extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

func _ready() -> void:
	# 1. Disable gerakan player sejenak saat layar masih hitam
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# 2. Setup Kamera
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()

	# 3. Fade In layar
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 4. Kembalikan kontrol player
	if player and player.has_method("enable_movement"):
		player.enable_movement()
