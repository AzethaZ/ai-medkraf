extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = $Camera2D
@onready var batang_pohon: Area2D = $BatangPohon

var is_interacting: bool = false

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
	if batang_pohon:
		if batang_pohon.has_signal("tree_interacted"):
			if not batang_pohon.tree_interacted.is_connected(_on_tree_interacted):
				batang_pohon.tree_interacted.connect(_on_tree_interacted)
		elif batang_pohon.has_signal("interacted"):
			if not batang_pohon.interacted.is_connected(_on_tree_interacted):
				batang_pohon.interacted.connect(_on_tree_interacted)

	# 3. Transisi Fade In Layar
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 4. Jalankan Animasi Auto-Walk Masuk dari Kiri
	await play_enter_animation()

# --- FUNGSI AUTO-WALK MASUK ---
func play_enter_animation() -> void:
	if not player:
		return

	if player.has_method("disable_movement"):
		player.disable_movement()

	if player.has_method("start_auto_walk"):
		player.start_auto_walk(1.0)

	var enter_tween = create_tween()
	var target_x = player.global_position.x + 70.0
	enter_tween.tween_property(player, "global_position:x", target_x, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await enter_tween.finished

	if player.has_method("stop_auto_walk"):
		player.stop_auto_walk()

	if player.has_method("enable_movement"):
		player.enable_movement()

# --- TRANSIKSI SAAT INTERAKSI BATANG POHON ---
func _on_tree_interacted() -> void:
	if is_interacting:
		return
	is_interacting = true

	# Disable kontrol pemain
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# --- DIALOG DENGAN DIALOGUE UI PLAYER ---
	if player and player.has_method("show_dialogue"):
		await player.show_dialogue("Aku bisa sembunyi di sini...", 2.5)
		await player.show_dialogue("Suasana mulai tenang... tapi aku merasa sangat mengantuk...", 2.5)
	else:
		await get_tree().create_timer(5.0).timeout

	# --- PENENTUAN TARGET SCENE ---
	var target_scene = "res://scene/Function/cutscene_pohon.tscn"
	if not ResourceLoader.exists(target_scene):
		target_scene = "res://scene/cutscene_pohon.tscn"
	if not ResourceLoader.exists(target_scene):
		target_scene = "res://scene/World/world_hutanbakar2.tscn"

	# --- FADE OUT & PINDAH SCENE ---
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		get_tree().change_scene_to_file(target_scene)
	elif SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)
