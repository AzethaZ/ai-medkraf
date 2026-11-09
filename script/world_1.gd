extends Node2D

@onready var player: Node2D = $Player


func _ready() -> void:
	# 0. MEMUTAR AUDIO DUNIA (Gunakan file audio yang sama untuk world 1, 2, dan 3)
	var ambience_file = preload("res://assets/audio/chinese_ambience.mp3")
	var bgm_file = preload("res://assets/audio/chinese_music2.mp3") # Sesuaikan path file BGM kamu

	if MusicManager:
		MusicManager.play_world_audio(ambience_file, bgm_file, 6, -12.0)

	# 1. Jika masih menggunakan node FadeOverlay lokal, sembunyikan/terangkan lebih dulu
	if has_node("FadeLayer/FadeOverlay"):
		$FadeLayer/FadeOverlay.visible = false

	# 2. Buka layar hitam dari Singleton SceneTransition
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 3. Aktifkan pergerakan player
	if player and player.has_method("enable_movement"):
		player.enable_movement()
