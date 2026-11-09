extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false) as Camera2D
@onready var peternak: Node2D = find_child("npc_peternak", true, false) as Node2D

# Percakapan cutscene peternakan di world_3
var farm_dialogues = [
	{"speaker_name": "Danum", "text": "Wah, banyak sekali ayam di sini! Apa mereka semua tinggal di tengah hutan?"}, # Line 0
	{"speaker_name": "Peternak", "text": "Haha, benar. Kami membiarkan ayam-ayam ini berkeliaran di area peternakan untuk mencari makanan alami."}, # Line 1
	{"speaker_name": "Danum", "text": "Huaaa, siapa kamu?"}, # Line 2
	{"speaker_name": "Peternak", "text": "Hoho, jangan terkejut begitu seperti melihat hantu saja. Aku adalah peternak ayam di hutan ini."}, # Line 3
	{"speaker_name": "Danum", "text": "Wah, anda beternak ayam di sini paman?"}, # Line 4
	{"speaker_name": "Peternak", "text": "Tentu saja, kami memanfaatkan hutan ini sebagai kandang ayam raksasa."}, # Line 5
	{"speaker_name": "Danum", "text": "Memangnya tidak takut ayamnya hilang atau pergi terlalu jauh?"}, # Line 6
	{"speaker_name": "Peternak", "text": "Kami sudah membuat pagar pembatas untuk itu…..Tapi sebenarnya, beberapa ayam kami baru saja terlepas karena pagar pembatas rusak terkena hujan deras."}, # Line 7
	{"speaker_name": "Danum", "text": "Terus, bagaimana sekarang?"}, # Line 8
	{"speaker_name": "Peternak", "text": "Ada beberapa ayam yang belum kembali. Kalau dibiarkan, mereka bisa tersesat lebih jauh ke dalam hutan. Aku juga belum sempat memperbaiki pagarnya."}, # Line 9
	{"speaker_name": "Danum", "text": "Hmmm, tenang saja paman aku bisa membantu mencari ayam-ayam itu!"}, # Line 10
	{"speaker_name": "Peternak", "text": "Benarkah? Wah, terima kasih! Tolong cari ayam-ayam yang terlepas itu. Setelah itu, kita perlu memperbaiki pagar agar kejadian seperti ini tidak terulang."} # Line 11
]

var default_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 0. MEMUTAR AUDIO DUNIA
	var ambience_file = preload("res://assets/audio/chinese_ambience.mp3")
	var bgm_file = preload("res://assets/audio/chinese_music2.mp3")

	if MusicManager:
		MusicManager.play_world_audio(ambience_file, bgm_file, 6.0, -12.0)

	# 1. Sambungkan Sinyal CutsceneTriggerArea Secara Otomatis
	var trigger_area = find_child("CutsceneTriggerArea", true, false) as Area2D
	if trigger_area:
		if not trigger_area.body_entered.is_connected(_on_cutscene_trigger_area_body_entered):
			trigger_area.body_entered.connect(_on_cutscene_trigger_area_body_entered)

	# 2. Disable gerakan player sejenak saat layar masih hitam
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# 3. Spawn Position
	var spawn_name: String = "SpawnPoint"
	if SceneTransition and "target_spawn_id" in SceneTransition and SceneTransition.target_spawn_id != "":
		spawn_name = SceneTransition.target_spawn_id
		SceneTransition.target_spawn_id = ""

	_move_player_to_spawn(spawn_name)

	# 4. Setup Kamera
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()
		camera_2d.limit_left = -900
		camera_2d.limit_right = 880
		default_offset = camera_2d.offset

	# 5. Fade In layar
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 6. Enable movement player
	if player and player.has_method("enable_movement"):
		player.enable_movement()


# --- PEMICU COLLISION AREA ---
func _on_cutscene_trigger_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player") or body.name.begins_with("CharacterBody2D"):
		var already_played: bool = false
		if "cutscene_world_3_done" in GameState:
			already_played = GameState.cutscene_world_3_done
		elif "cutscene_world_3_done" in QuestManager:
			already_played = QuestManager.cutscene_world_3_done

		if not already_played:
			var trigger_area = find_child("CutsceneTriggerArea", true, false) as Area2D
			if trigger_area:
				trigger_area.set_deferred("monitoring", false)

			await run_farm_cutscene()


func run_farm_cutscene() -> void:
	# 1. Kunci pergerakan manual
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# 2. Danum melangkah kecil di awal (+35px) menggunakan animasi walk
	_play_walk(player)
	var walk_tween = create_tween()
	walk_tween.tween_property(player, "global_position:x", player.global_position.x + 35.0, 0.6).set_trans(Tween.TRANS_LINEAR)
	await walk_tween.finished
	_play_idle(player)

	# 3. Cari node NPC Peternak & Dialogue Pivots
	if not peternak:
		peternak = find_child("npc_peternak", true, false) as Node2D

	var peternak_target: Node2D = peternak
	if peternak and peternak.has_node("DialoguePivot"):
		peternak_target = peternak.get_node("DialoguePivot") as Node2D

	var player_target: Node2D = player
	if player and player.has_node("DialoguePivot"):
		player_target = player.get_node("DialoguePivot") as Node2D

	# 4. Loop Percakapan & Kontrol Kamera/Pergerakan
	if DialogueManager:
		var current_camera_state: String = "player"

		for i in range(farm_dialogues.size()):
			var item = farm_dialogues[i]
			var is_peternak: bool = (item["speaker_name"] == "Peternak")
			var target_speaker: Node2D = peternak_target if is_peternak else player_target

			# SISTEM KAMERA: Pindahkan kamera DULU ke NPC sampai diam
			if camera_2d:
				if is_peternak and current_camera_state != "peternak":
					current_camera_state = "peternak"
					var camera_tween = create_tween()
					camera_tween.tween_property(camera_2d, "offset", Vector2(300, 0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					await camera_tween.finished

				elif not is_peternak and current_camera_state != "player" and i < 5:
					current_camera_state = "player"
					var camera_tween = create_tween()
					camera_tween.tween_property(camera_2d, "offset", default_offset, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					await camera_tween.finished

			# TAMPILKAN DIALOG
			if DialogueManager.has_method("start_dialogue"):
				await DialogueManager.start_dialogue([item["text"]], target_speaker)
			elif DialogueManager.has_method("show_dialogue"):
				await DialogueManager.show_dialogue([item["text"]], target_speaker)

			if DialogueManager.has_signal("dialogue_ended"):
				await DialogueManager.dialogue_ended
			elif DialogueManager.has_signal("dialogue_finished"):
				await DialogueManager.dialogue_finished

			# SETELAH LINE 5 ("Tentu saja, kami memanfaatkan hutan ini..."):
			# Danum melangkah ke kanan dengan animasi walk, SEMENTARA KAMERA TETAP DIAM DI NPC!
			if i == 5:
				await _walk_danum_keep_camera_still(220.0)

	# Reset offset kamera netral setelah cutscene selesai
	if camera_2d:
		var reset_tween = create_tween()
		reset_tween.tween_property(camera_2d, "offset", default_offset, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Tandai cutscene world 3 selesai
	if "cutscene_world_3_done" in GameState:
		GameState.cutscene_world_3_done = true
	elif "cutscene_world_3_done" in QuestManager:
		QuestManager.cutscene_world_3_done = true

	# Mulai Quest Ayam
	if QuestManager and QuestManager.has_method("start_quest"):
		QuestManager.start_quest("quest_ayam_1")

	if player and player.has_method("enable_movement"):
		player.enable_movement()


# --- HELPER DANUM BERJALAN DENGAN KAMERA TETAP DIAM DI NPC ---
func _walk_danum_keep_camera_still(distance: float) -> void:
	# 1. Paksa putar animasi walk
	_play_walk(player)

	var move_tween = create_tween().set_parallel(true)
	
	# 2. Geser posisi fisik Danum ke kanan (+220px) selama 2.0 detik agar langkah kaki terlihat jelas
	move_tween.tween_property(player, "global_position:x", player.global_position.x + distance, 2.0).set_trans(Tween.TRANS_LINEAR)
	
	# 3. Kompensasi offset kamera agar kamera 100% DIAM menyorot Peternak
	if camera_2d:
		var target_offset_x = camera_2d.offset.x - distance
		move_tween.tween_property(camera_2d, "offset:x", target_offset_x, 2.0).set_trans(Tween.TRANS_LINEAR)

	# Tunggu sampai gerakan jalan selesai sepenuhnya
	await move_tween.finished
	
	# Kembalikan ke animasi idle/default setelah benar-benar sampai di posisi tujuan
	_play_idle(player)


# --- HELPER PEMUTAR ANIMASI 100% PRESISI ---
func _play_walk(char_node: Node2D) -> void:
	if not char_node: return
	
	if char_node.has_method("play_cutscene_walk"):
		char_node.play_cutscene_walk()
		return

	var sprite = char_node.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")


func _play_idle(char_node: Node2D) -> void:
	if not char_node: return
	
	if char_node.has_method("play_cutscene_idle"):
		char_node.play_cutscene_idle()
		return

	var sprite = char_node.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
		elif sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")


# --- FUNGSI HELPER PEMINDAHAN POSISI SPAWN ---
func _move_player_to_spawn(spawn_name: String) -> void:
	var spawn_node = find_child(spawn_name, true, false)
	if spawn_node and player:
		player.global_position = spawn_node.global_position
