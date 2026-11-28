extends Node2D

@export_group("Rooster Victory Cutscene SFX")
@export var rooster_crow_sfx: AudioStream
@export var rooster_fly_sfx: AudioStream

@onready var player: Node2D = $Player

func _ready() -> void:
	# Ubah warna hanya pada AnimatedSprite2D milik Player khusus di world_2
	var player_node := get_node_or_null("Player")
	if player_node and player_node.has_node("AnimatedSprite2D"):
		var player_sprite: AnimatedSprite2D = player_node.get_node("AnimatedSprite2D")
		player_sprite.modulate = Color(0.92, 0.84, 1.0, 1.0) # Sesuaikan tint ungu/senja world_2
	# 1. Atur batas kamera
	var player_cam := $Player.get_node_or_null("Camera2D") as Camera2D
	if player_cam:
		player_cam.limit_left = -480
		player_cam.limit_right = 480
		player_cam.limit_top = -290
		player_cam.limit_smoothed = true

	# 2. Sembunyikan FadeOverlay lokal jika ada
	if has_node("FadeLayer/FadeOverlay"):
		$FadeLayer/FadeOverlay.visible = false

	var is_rooster_defeated: bool = GameState and GameState.get_meta("rooster_defeated", false)
	var play_victory_cutscene: bool = GameState and GameState.get_meta("rooster_defeated_pending_popup", false)
	var rooster_node := get_node_or_null("Rooster") as Node2D
	var battle_finish := get_node_or_null("BattleFinish")

	# Jika sudah pernah menang sebelumnya (bukan baru selesai bertarung), langsung hapus ayam & putar BGM
	if is_rooster_defeated and not play_victory_cutscene:
		if rooster_node:
			rooster_node.queue_free()
		_play_world_audio()
		if SceneTransition and SceneTransition.has_method("fade_in"):
			SceneTransition.fade_in()
		if player and player.has_method("enable_movement"):
			player.enable_movement()
		return

	# === JALANKAN CUTSCENE IN-GAME SETELAH MENANG ===
	if play_victory_cutscene:
		GameState.remove_meta("rooster_defeated_pending_popup")

		# Posisikan Danum di titik BattleFinish, hadapkan ke kiri (ke arah Rooster), & kunci geraknya
		if player and battle_finish:
			player.global_position = battle_finish.global_position
			var player_sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if player_sprite:
				player_sprite.flip_h = true
			elif player.get_node_or_null("Sprite2D"):
				player.get_node("Sprite2D").flip_h = true

		if player and player.has_method("disable_movement"):
			player.disable_movement()

		# Set ayam langsung dalam pose/animasi death sebelum layar terbuka
		if rooster_node:
			var rooster_sprite := rooster_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if rooster_sprite and rooster_sprite.sprite_frames.has_animation("death"):
				rooster_sprite.sprite_frames.set_animation_loop("death", false)
				rooster_sprite.play("death")

		# Buka layar hitam dari arena -> terlihat Danum & ayam dalam pose death
		if SceneTransition and SceneTransition.has_method("fade_in"):
			await SceneTransition.fade_in()

		await get_tree().create_timer(0.3).timeout

		# A. Putar suara ayam berkokok
		if rooster_crow_sfx:
			var crow_player := AudioStreamPlayer.new()
			crow_player.stream = rooster_crow_sfx
			add_child(crow_player)
			crow_player.play()
			crow_player.finished.connect(crow_player.queue_free)

		# B. Munculkan dialog lewat DialogueManager
		if rooster_node and DialogueManager:
			var lines: Array[String] = [
				"Kukuruyuk...!!",
				"(Suaraku tidak pernah didengar, padahal kita ingin hidup bebas!)"
			]
			DialogueManager.start_dialogue(lines, rooster_node)

			if DialogueManager.has_signal("dialogue_finished"):
				await DialogueManager.dialogue_finished
			elif DialogueManager.has_signal("dialog_finished"):
				await DialogueManager.dialog_finished

		# C. Layar fade ke hitam -> bunyi suara ayam terbang -> hapus node Rooster
		if SceneTransition and SceneTransition.has_method("fade_out"):
			await SceneTransition.fade_out()

		if rooster_fly_sfx:
			var fly_player := AudioStreamPlayer.new()
			fly_player.stream = rooster_fly_sfx
			add_child(fly_player)
			fly_player.play()
			fly_player.finished.connect(fly_player.queue_free)

		if rooster_node:
			rooster_node.queue_free()

		await get_tree().create_timer(1.1).timeout

		if QuestManager:
			QuestManager.complete_quest("quest_ayam_3")

		# D. Cutscene selesai -> mulai putar BGM & ambience world_1 sebelum layar dibuka
		_play_world_audio()

		# E. Buka layar hitam kembali -> ayam sudah hilang & Danum bisa jalan
		if SceneTransition and SceneTransition.has_method("fade_in"):
			await SceneTransition.fade_in()

		if player and player.has_method("enable_movement"):
			player.enable_movement()
		return

	# === KONDISI NORMAL MASUK WORLD_1 (BELUM BERTARUNG) ===
	_play_world_audio()
	if SceneTransition and SceneTransition.has_method("fade_in"):
		SceneTransition.fade_in()
	if player and player.has_method("enable_movement"):
		player.enable_movement()


func _play_world_audio() -> void:
	var ambience_file = preload("res://assets/audio/chinese_ambience.mp3")
	var bgm_file = preload("res://assets/audio/chicken/chinese_music_1.mp3")
	if MusicManager:
		MusicManager.play_world_audio(ambience_file, bgm_file, 6, -12.0)
