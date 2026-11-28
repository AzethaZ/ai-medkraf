extends CharacterBody2D

@export_group("Cutscene Trigger & Auto Walk")
@export var auto_walk_speed: float = 95.0
@export var stop_distance_x: float = 130.0 # Jarak berhenti Danum di depan NPC
@export var auto_walk_max_duration: float = 4.0
@export var camera_pan_right_offset: float = 55.0 # Seberapa jauh kamera geser ke kanan saat berhenti
@export var camera_pan_duration: float = 0.55 # Durasi animasi geser kamera

@export_group("Final Cutscene")
@export var final_cutscene_image: Texture2D # Drag gambar cutscene ke sini di Inspector
@export var cutscene_danum_pivot_pos: Vector2 = Vector2(180, 210) # Posisi bubble Danum di layar cutscene (640x360)
@export var cutscene_npc_pivot_pos: Vector2 = Vector2(460, 190) # Posisi bubble Pengelola di layar cutscene (640x360)
@export var cutscene_fade_duration: float = 0.35

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var chat_detection: Area2D = $chat_detection
@onready var interact_icon: Sprite2D = $InteractIcon
@onready var dialogue_pivot: Marker2D = $DialoguePivot
@onready var cutscene_trigger: Area2D = get_node_or_null("CutsceneTrigger")

var player_in_range: bool = false
var player_ref: Node2D = null
var is_talking: bool = false
var is_cutscene_walking: bool = false
var hover_tween: Tween = null
var base_icon_y: float = 0.0

# Node sementara untuk cutscene gambar
var cutscene_layer: CanvasLayer = null
var cutscene_fade_rect: ColorRect = null
var cutscene_p_pivot: Marker2D = null
var cutscene_npc_pivot: Marker2D = null


func _ready() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		elif animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")

	if interact_icon:
		base_icon_y = interact_icon.position.y
		interact_icon.visible = false

	if chat_detection:
		if not chat_detection.body_entered.is_connected(_on_chat_detection_body_entered):
			chat_detection.body_entered.connect(_on_chat_detection_body_entered)
		if not chat_detection.body_exited.is_connected(_on_chat_detection_body_exited):
			chat_detection.body_exited.connect(_on_chat_detection_body_exited)

	if cutscene_trigger:
		if GameState.hotel_quest_stage > 0:
			cutscene_trigger.queue_free()
		else:
			if not cutscene_trigger.body_entered.is_connected(_on_cutscene_trigger_body_entered):
				cutscene_trigger.body_entered.connect(_on_cutscene_trigger_body_entered)


func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_talking and not is_cutscene_walking and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_start_interaction()


func _on_cutscene_trigger_body_entered(body: Node2D) -> void:
	if is_talking or is_cutscene_walking:
		return
	if GameState.hotel_quest_stage != 0:
		return

	if body.is_in_group("player") or body.name == "Player":
		player_ref = body
		_start_intro_auto_walk_cutscene()


func _start_intro_auto_walk_cutscene() -> void:
	is_cutscene_walking = true
	is_talking = true

	if interact_icon:
		interact_icon.visible = false

	# Kunci kontrol player
	if player_ref:
		if player_ref.has_method("disable_movement"):
			player_ref.disable_movement()
		elif "can_move" in player_ref:
			player_ref.can_move = false

		if player_ref is CharacterBody2D:
			player_ref.velocity = Vector2.ZERO

	# Hadapkan NPC ke arah player
	if player_ref and animated_sprite:
		var face_player_dir: float = sign(player_ref.global_position.x - global_position.x)
		if face_player_dir != 0.0:
			animated_sprite.flip_h = (face_player_dir < 0.0)

	# 1. Jalankan auto-walk sampai berhenti di depan NPC
	await _auto_walk_player_towards_npc()
	is_cutscene_walking = false

	# 2. Geser kamera sedikit ke kanan setelah berhenti
	var player_cam := _find_camera(player_ref)
	var orig_cam_offset_x: float = 0.0
	if player_cam:
		orig_cam_offset_x = player_cam.offset.x
		var pan_right := create_tween()
		pan_right.tween_property(player_cam, "offset:x", orig_cam_offset_x + camera_pan_right_offset, camera_pan_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		await pan_right.finished

	# 3. Mulai dialog tahap 1
	await _play_stage_1_start_dialogue()

	if cutscene_trigger and is_instance_valid(cutscene_trigger):
		cutscene_trigger.queue_free()

	# 4. Kembalikan posisi offset kamera ke semula setelah dialog selesai
	if is_instance_valid(player_cam):
		var pan_back := create_tween()
		pan_back.tween_property(player_cam, "offset:x", orig_cam_offset_x, camera_pan_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await pan_back.finished

	# 5. Kembalikan kontrol player
	if is_instance_valid(player_ref):
		if player_ref.has_method("enable_movement"):
			player_ref.enable_movement()
		elif "can_move" in player_ref:
			player_ref.can_move = true

	is_talking = false
	if player_in_range and interact_icon:
		interact_icon.visible = true
		_start_hover_tween()


func _find_camera(target_player: Node2D) -> Camera2D:
	if is_instance_valid(target_player):
		var cam := target_player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			return cam
	return get_viewport().get_camera_2d()


func _auto_walk_player_towards_npc() -> void:
	if not is_instance_valid(player_ref):
		return

	var walk_dir: float = sign(global_position.x - player_ref.global_position.x)
	if walk_dir == 0.0:
		walk_dir = 1.0

	player_ref.set_physics_process(false)

	var player_anim: AnimatedSprite2D = player_ref.get_node_or_null("AnimatedSprite2D")
	if is_instance_valid(player_anim):
		player_anim.flip_h = (walk_dir < 0.0)
	if player_ref.has_method("play_cutscene_walk"):
		player_ref.play_cutscene_walk()
	elif is_instance_valid(player_anim):
		player_anim.play("walk")

	var elapsed: float = 0.0
	while is_instance_valid(player_ref) and elapsed < auto_walk_max_duration:
		if abs(global_position.x - player_ref.global_position.x) <= stop_distance_x:
			break

		var delta: float = get_physics_process_delta_time()
		elapsed += delta

		if player_ref is CharacterBody2D:
			player_ref.velocity = Vector2(walk_dir * auto_walk_speed, 0.0)
			player_ref.move_and_slide()
		else:
			player_ref.global_position.x += walk_dir * auto_walk_speed * delta

		await get_tree().physics_frame

	if is_instance_valid(player_ref):
		if player_ref is CharacterBody2D:
			player_ref.velocity = Vector2.ZERO
		if player_ref.has_method("play_cutscene_idle"):
			player_ref.play_cutscene_idle()
		elif is_instance_valid(player_anim):
			player_anim.play("default")

		var face_npc_dir: float = sign(global_position.x - player_ref.global_position.x)
		if is_instance_valid(player_anim) and face_npc_dir != 0.0:
			player_anim.flip_h = (face_npc_dir < 0.0)

		player_ref.set_physics_process(true)


func _face_player_towards_npc() -> void:
	if not is_instance_valid(player_ref):
		return
	var p_anim := player_ref.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if p_anim:
		p_anim.flip_h = global_position.x < player_ref.global_position.x


func _start_interaction() -> void:
	if is_talking or is_cutscene_walking:
		return

	is_talking = true
	if interact_icon:
		interact_icon.visible = false

	if player_ref and player_ref.has_method("disable_movement"):
		player_ref.disable_movement()

	if player_ref and animated_sprite:
		animated_sprite.flip_h = player_ref.global_position.x < global_position.x
	_face_player_towards_npc()

	if QuestManager and QuestManager.get_quest_status("quest_hotel_2") == "READY_TO_SUBMIT":
		await _play_final_dialogue()
	elif QuestManager and QuestManager.get_quest_status("quest_hotel_1") == "READY_TO_SUBMIT":
		await _play_stage_2_start_dialogue()
	else:
		match GameState.hotel_quest_stage:
			0:
				await _play_stage_1_start_dialogue()
			1:
				await _play_stage_1_reminder()
			2:
				await _play_stage_2_start_dialogue()
			3:
				await _play_stage_2_reminder()
			4:
				await _play_final_dialogue()
			_:
				await _play_post_quest_dialogue()

	if player_ref and player_ref.has_method("enable_movement"):
		player_ref.enable_movement()

	is_talking = false
	if player_in_range and interact_icon:
		interact_icon.visible = true
		_start_hover_tween()


# --- TAHAP 1: KENALAN AWAL & QUEST RUMAH 1 ---
func _play_stage_1_start_dialogue() -> void:
	var p := _get_player_pivot()
	var npc := _get_npc_pivot()

	await _say(["Halo? Tempat apa ini? Bangunannya unik sekali, seperti sarang burung!"], p)
	await _say(["Oh, halo! Selamat datang! Ini adalah salah satu penginapan yang ada di sini."], npc)
	await _say(["Penginapan di tengah hutan? Apa tidak mengganggu pohon-pohon di sekitarnya?"], p)

	await _say(["Tentu saja tidak, kami berusaha menjaga penginapan dengan menyelaraskan kondisi alam di sekitar."], npc)
	await _say(["Maka sangat perlu bagi kami memelihara hutan dan lampu tetap menyala."], npc)

	await _say(["Waaah, menarik sekali! Tapi... kenapa tempat ini terlihat berantakan?"], p)

	await _say(["Hujan deras semalam membuat debu dan kotoran masuk ke dalam penginapan."], npc)
	await _say(["Padahal sebentar lagi akan ada tamu yang datang."], npc)

	await _say(["Kalau begitu, boleh aku bantu membersihkannya?"], p)

	await _say(["Tentu saja! Terima kasih banyak, ya."], npc)
	await _say(["Pertama, tolong masuk ke Penginapan 1 dan bersihkan 2 bagian yang kotor di sana."], npc)

	GameState.hotel_quest_stage = 1
	if QuestManager and QuestManager.has_method("start_quest"):
		QuestManager.start_quest("quest_hotel_1")


func _play_stage_1_reminder() -> void:
	var npc := _get_npc_pivot()

	await _say(["Tolong masuk ke Penginapan 1 dulu, ya."], npc)
	await _say(["Masih ada bagian yang perlu dibersihkan di dalamnya!"], npc)


# --- TAHAP 2: LAPOR RUMAH 1 & QUEST RUMAH 2 ---
func _play_stage_2_start_dialogue() -> void:
	var p := _get_player_pivot()
	var npc := _get_npc_pivot()

	if QuestManager and QuestManager.has_method("complete_quest"):
		QuestManager.complete_quest("quest_hotel_1", true)

	await _say(["Penginapan 1 sudah kubersihkan semua!"], p)

	await _say(["Wah, cepat dan rapi sekali! Terima kasih banyak, Danum."], npc)
	await _say(["Boleh minta tolong satu lagi? Di Penginapan 2 juga ada 2 bagian yang kotor dan berdebu."], npc)

	await _say(["Siap! Biar aku bersihkan Penginapan 2 sekarang."], p)

	GameState.hotel_quest_stage = 3
	if QuestManager and QuestManager.has_method("start_quest"):
		QuestManager.start_quest("quest_hotel_2")


func _play_stage_2_reminder() -> void:
	var npc := _get_npc_pivot()

	await _say(["Penginapan 2 masih perlu dirapikan."], npc)
	await _say(["Tolong bantu bersihkan 2 bagian di dalamnya sebelum tamu datang, ya!"], npc)


# --- TAHAP AKHIR: LAPOR RUMAH 2 & DIALOG PENUTUP ---
# --- TAHAP AKHIR: LAPOR RUMAH 2 & DIALOG PENUTUP ---
func _play_final_dialogue() -> void:
	var p := _get_player_pivot()
	var npc := _get_npc_pivot()

	if QuestManager and QuestManager.has_method("complete_quest"):
		QuestManager.complete_quest("quest_hotel_2", true)

	await _say(["Sudah selesai! Sekarang tempatnya jadi jauh lebih bersih dan rapi."], p)
	await _say(["Wah, terima kasih banyak! Para tamu pasti akan lebih nyaman sekarang."], npc)

	await _enter_image_cutscene()

	await _say(["Apakah penginapan ini selalu ramai dikunjungi orang?"], cutscene_p_pivot)
	await _say(["Cukup ramai, terutama mereka yang ingin menikmati suasana alam. Penginapan ini juga memberikan pekerjaan bagi masyarakat sekitar, mulai dari mengelola penginapan hingga menyediakan makanan dan kerajinan."], cutscene_npc_pivot)
	await _say(["Jadi, hutan juga bisa memberikan manfaat bagi banyak orang melalui pariwisata, ya?"], cutscene_p_pivot)
	await _say(["Betul. Tapi kita juga harus bertanggung jawab menjaga lingkungan agar keindahan alamnya tetap bisa dinikmati."], cutscene_npc_pivot)
	await _say(["Aku mengerti sekarang. Ternyata manusia dan hutan bisa saling memberikan manfaat selama kita tahu cara menjaganya."], cutscene_p_pivot)

	await _exit_image_cutscene()

	await _say(["Terima kasih banyak atas bantuanmu membersihkan kedua penginapan, Danum!"], npc)
	await _say(["Semoga perjalananmu berikutnya berjalan lancar."], npc)

	GameState.hotel_quest_stage = 5

	# Tempelkan layar hitam ke root (persisten lintas scene) agar tidak berkedip saat ganti scene
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	get_tree().root.add_child(fade_layer)
	get_tree().root.set_meta("hotel_to_world7_fade", fade_layer)

	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 1.3)
	await tw.finished

	get_tree().change_scene_to_file("res://scene/World/world_7.tscn")


func _play_post_quest_dialogue() -> void:
	var npc := _get_npc_pivot()

	await _say(["Terima kasih banyak atas bantuanmu membersihkan kedua penginapan, Danum!"], npc)
	await _say(["Semoga perjalananmu berikutnya berjalan lancar."], npc)


# --- CUTSCENE GAMBAR & PIVOT KHUSUS ---
func _enter_image_cutscene() -> void:
	cutscene_layer = CanvasLayer.new()
	cutscene_layer.layer = 10
	add_child(cutscene_layer)

	var bg_image := TextureRect.new()
	bg_image.texture = final_cutscene_image
	bg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutscene_layer.add_child(bg_image)

	cutscene_p_pivot = Marker2D.new()
	cutscene_p_pivot.position = cutscene_danum_pivot_pos
	cutscene_layer.add_child(cutscene_p_pivot)

	cutscene_npc_pivot = Marker2D.new()
	cutscene_npc_pivot.position = cutscene_npc_pivot_pos
	cutscene_layer.add_child(cutscene_npc_pivot)

	cutscene_fade_rect = ColorRect.new()
	cutscene_fade_rect.color = Color(0, 0, 0, 1.0)
	cutscene_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutscene_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutscene_layer.add_child(cutscene_fade_rect)

	var tween := create_tween()
	tween.tween_property(cutscene_fade_rect, "color:a", 0.0, cutscene_fade_duration)
	await tween.finished


func _exit_image_cutscene() -> void:
	if not cutscene_layer:
		return

	var tween_in := create_tween()
	tween_in.tween_property(cutscene_fade_rect, "color:a", 1.0, cutscene_fade_duration)
	await tween_in.finished

	for child in cutscene_layer.get_children():
		if child != cutscene_fade_rect:
			child.queue_free()

	cutscene_p_pivot = null
	cutscene_npc_pivot = null

	var tween_out := create_tween()
	tween_out.tween_property(cutscene_fade_rect, "color:a", 0.0, cutscene_fade_duration)
	await tween_out.finished

	cutscene_layer.queue_free()
	cutscene_layer = null
	cutscene_fade_rect = null


# --- UTILITY DIALOGUE & NODE ---
func _say(lines: Array[String], pivot: Node2D) -> void:
	if not DialogueManager:
		return

	DialogueManager.start_dialogue(lines, pivot)
	if "is_active" in DialogueManager:
		while DialogueManager.is_active:
			await get_tree().process_frame
	elif DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	elif DialogueManager.has_signal("dialogue_ended"):
		await DialogueManager.dialogue_ended


func _get_npc_pivot() -> Node2D:
	if dialogue_pivot:
		return dialogue_pivot
	return self


func _get_player_pivot() -> Node2D:
	if player_ref:
		var custom_pivot := player_ref.get_node_or_null("DialoguePivot") as Node2D
		if custom_pivot:
			return custom_pivot
		return player_ref
	return _get_npc_pivot()


func _on_chat_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true
		player_ref = body
		if not is_talking and not is_cutscene_walking and interact_icon:
			interact_icon.visible = true
			_start_hover_tween()


func _on_chat_detection_body_exited(body: Node2D) -> void:
	if body == player_ref or body.is_in_group("player") or body.name == "Player":
		player_in_range = false
		if not is_cutscene_walking and not is_talking:
			player_ref = null
		_stop_hover_tween()
		if interact_icon:
			interact_icon.visible = false


func _start_hover_tween() -> void:
	if not interact_icon:
		return
	_stop_hover_tween()
	interact_icon.position.y = base_icon_y
	hover_tween = create_tween().set_loops()
	hover_tween.tween_property(interact_icon, "position:y", base_icon_y - 4.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_tween.tween_property(interact_icon, "position:y", base_icon_y, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_hover_tween() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	if interact_icon:
		interact_icon.position.y = base_icon_y
