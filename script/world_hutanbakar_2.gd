extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

func _ready() -> void:
	# 1. Kunci pergerakan player sejenak
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# 2. Setup kamera jika ada
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()

	# 3. MEMBUKA LAYAR (FADE IN) DARI HITAM KE TERANG
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 4. Aktifkan kembali pergerakan player setelah layar terang penuh
	if player and player.has_method("enable_movement"):
		player.enable_movement()
