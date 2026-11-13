extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = $Camera2D
@onready var batang_pohon: Area2D = $BatangPohon
@onready var npc_chaser: Node2D = $NPC_Chaser

@onready var chaser_step_player: AudioStreamPlayer = find_child("ChaserStepPlayer", true, false) as AudioStreamPlayer

var is_interacting: bool = false

func _ready() -> void:
	# 0. Sembunyikan NPC Chaser & matikan AI kejar bawaannya saat scene baru dimuat
	if npc_chaser:
		npc_chaser.visible = false
		npc_chaser.set_physics_process(false)
		npc_chaser.set_process(false)

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

# --- TRANSAKSI SAAT INTERAKSI BATANG POHON ---
func _on_tree_interacted() -> void:
	if is_interacting:
		return
	is_interacting = true
	
	# 1. Kunci pergerakan Danum
	if player and player.has_method("disable_movement"):
		player.disable_movement()
		
	# 2. SETUP DIALOG MC (DANUM) DENGAN FORMAT DICTIONARY
	var mc_dialogue: Array = [
		{
			"speaker": "mc",
			"text": "Aku bisa sembunyi di sini..."
		},
		{
			"speaker": "mc",
			"text": "Semoga mereka tidak menemukanku"
		}
	]
	
	# 3. JALANKAN DIALOG DANUM & TUNGGU SIGNAL DIALOGUE FINISHED
	if DialogueManager and DialogueManager.has_method("start_dialogue"):
		DialogueManager.start_dialogue(mc_dialogue)
		if DialogueManager.has_signal("dialogue_finished"):
			await DialogueManager.dialogue_finished
		else:
			await get_tree().create_timer(5.0).timeout
	else:
		await get_tree().create_timer(4.0).timeout
		
	# 4. CUTSCENE: DANUM FADE HILANG & NPC CHASER LEWAT DARI KIRI KE KANAN
	await _play_chaser_passing_sequence()
		
	# 5. SETELAH CHASER LEWAT -> FADE OUT & PINDAH SCENE
	var target_scene = "res://scene/Function/cutscene_pohon.tscn"
	if not ResourceLoader.exists(target_scene):
		target_scene = "res://scene/cutscene_pohon.tscn"
	if not ResourceLoader.exists(target_scene):
		target_scene = "res://scene/World/world_hutanbakar2.tscn"
		
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		get_tree().change_scene_to_file(target_scene)
	elif SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)

# --- FUNGSI CUTSCENE CHASER MELINTAS ---
func _play_chaser_passing_sequence() -> void:
	# A. Danum memudar (fade out) bersembunyi di balik pohon
	if player:
		var fade_out_tween = create_tween()
		fade_out_tween.tween_property(player, "modulate:a", 0.0, 0.5)
		await fade_out_tween.finished
		
	await get_tree().create_timer(0.4).timeout
	
	# B. Munculkan NPC Chaser dari kiri luar layar ke kanan luar layar
	if npc_chaser:
		var ground_y = player.global_position.y if player else npc_chaser.global_position.y
		npc_chaser.global_position = Vector2(-120.0, ground_y)
		npc_chaser.visible = true
		
		# Pastikan animasi jalan/lari aktif dan menghadap ke kanan
		if npc_chaser.has_node("AnimatedSprite2D"):
			var anim = npc_chaser.get_node("AnimatedSprite2D")
			anim.flip_h = false # Ubah ke true jika gambar aslinya menghadap kiri
			if anim.sprite_frames.has_animation("run"):
				anim.play("run")
			elif anim.sprite_frames.has_animation("walk"):
				anim.play("walk")
				
		# Gerakkan dari kiri (-120) ke kanan luar layar (1150) selama 5 detik
		var walk_tween = create_tween()
		walk_tween.tween_property(npc_chaser, "global_position:x", 1150.0, 5.0)
		
		# --- MULAI SUARA LANGKAH KAKI CHASER MENGULANG ---
		var step_tween: Tween
		if chaser_step_player and chaser_step_player.stream:
			step_tween = create_tween().set_loops()
			step_tween.tween_callback(func():
				chaser_step_player.pitch_scale = randf_range(0.95, 1.05) # Sedikit variasi nada agar natural
				chaser_step_player.play()
			)
			# Jeda antar langkah kaki (ubah 0.35 menjadi lebih kecil jika ingin langkah lebih cepat, misal 0.25)
			step_tween.tween_interval(0.35)
		
		# Tunggu 1.5 detik sampai dia masuk ke layar, lalu keluarkan dialog mengikuti kepalanya
		await get_tree().create_timer(1.5).timeout
		if DialogueManager and DialogueManager.has_method("start_dialogue"):
			var chaser_dialogue: Array = [
				{
					"speaker": "npc",
					"text": "Kemana dia pergi?!"
				}
			]
			DialogueManager.start_dialogue(chaser_dialogue, npc_chaser)
			
		# Tunggu sampai NPC Chaser selesai keluar ke sisi kanan layar
		await walk_tween.finished
		
		# --- HENTIKAN PENGULANGAN SUARA LANGKAH KAKI ---
		if step_tween:
			step_tween.kill()
		if chaser_step_player:
			chaser_step_player.stop()
		
		# Tutup kotak dialog jika masih terbuka saat chaser sudah keluar layar
		if DialogueManager and DialogueManager.get("is_active") == true:
			if DialogueManager.has_method("end_dialogue"):
				DialogueManager.end_dialogue()
				
		npc_chaser.visible = false
		
	await get_tree().create_timer(0.4).timeout
