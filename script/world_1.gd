extends Node2D

@onready var player: Node2D = $Player

func _ready() -> void:
	# 1. Jika masih menggunakan node FadeOverlay lokal, sembunyikan/terangkan lebih dulu
	if has_node("FadeLayer/FadeOverlay"):
		$FadeLayer/FadeOverlay.visible = false

	# 2. Buka layar hitam dari Singleton SceneTransition
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 3. Aktifkan pergerakan player
	if player and player.has_method("enable_movement"):
		player.enable_movement()
