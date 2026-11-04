extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = $Camera2D
@onready var batang_pohon: Area2D = $BatangPohon

func _ready() -> void:
	# 1. Setup Kamera Ruangan
	if player and player.has_node("Camera2D"):
		var player_cam = player.get_node("Camera2D") as Camera2D
		if player_cam:
			player_cam.enabled = false

	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()

	# 2. Hubungkan Signal Batang Pohon
	if batang_pohon and batang_pohon.has_signal("tree_interacted"):
		if not batang_pohon.tree_interacted.is_connected(_on_tree_interacted):
			batang_pohon.tree_interacted.connect(_on_tree_interacted)

	# 3. Transisi Fade In Layar
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 4. Jalankan Animasi Auto-Walk Masuk dari Kiri
	await play_enter_animation()

# --- FUNGSI AUTO-WALK MASUK ---

func play_enter_animation() -> void:
	if not player:
		return

	# Kunci input manual pemain selama animasi masuk berlangsung
	if player.has_method("disable_movement"):
		player.disable_movement()

	# Mulai animasi jalan di script Player (jika ada)
	if player.has_method("start_auto_walk"):
		player.start_auto_walk(1.0)

	# Geser posisi Danum ke kanan sejauh 70 piksel selama 0.9 detik
	var enter_tween = create_tween()
	var target_x = player.global_position.x + 70.0
	enter_tween.tween_property(player, "global_position:x", target_x, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await enter_tween.finished

	# Hentikan animasi jalan otomatis
	if player.has_method("stop_auto_walk"):
		player.stop_auto_walk()

	# Kembalikan kontrol manual ke pemain
	if player.has_method("enable_movement"):
		player.enable_movement()

# --- TRANSISI SAAT INTERAKSI BATANG POHON ---

func _on_tree_interacted() -> void:
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# Arahkan target scene ke scene Cutscene
	var target_scene = "res://scene/Function/cutscene_pohon.tscn"
	if not ResourceLoader.exists(target_scene):
		target_scene = "res://scene/cutscene_pohon.tscn"

	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(target_scene)
	elif SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		get_tree().change_scene_to_file(target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)
