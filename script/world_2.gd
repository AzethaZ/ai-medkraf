extends Node2D

@onready var player: Node2D = $Player

func _ready() -> void:
	# 1. BUKA EDAN LAYAR DARI HITAM (FADE IN)
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 2. AKTIFKAN KEMBALI KONTROL PLAYER
	if player and player.has_method("enable_movement"):
		player.enable_movement()
