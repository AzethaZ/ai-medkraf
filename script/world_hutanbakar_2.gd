extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

func _ready() -> void:
	# 1. SETUP KAMERA DI HUTAN BAKAR 2
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()

	# 2. PENTING: BUKA EDAN LAYAR DARI HITAM (FADE IN)
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 3. KEMBALIKAN PERGERAKAN PLAYER
	if player and player.has_method("enable_movement"):
		player.enable_movement()
