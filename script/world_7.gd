extends Node2D

@export_group("Cutscene World 7 Settings")
@export var auto_walk_speed: float = 72.0 # Kecepatan Danum berjalan otomatis ke kiri
@export var stop_distance_from_enggang: float = 205.0 # Jarak berhenti Danum dari NPC_Enggang
@export var extra_start_offset_right: float = 120.0 # Tambahan jarak spawn ke kanan agar jalan lebih panjang
@export var camera_pan_left_offset: float = 80.0 # Seberapa jauh kamera geser ke kiri setelah fade-in selesai
@export var camera_pan_duration: float = 0.85 # Durasi gerakan kamera bergeser ke kiri
@export var camera_pan_return_duration: float = 0.65 # Durasi kamera kembali ke posisi semula setelah dialog
@export var intro_black_steps_duration: float = 1.4 # Durasi suara langkah kaki di layar gelap sebelum world_7 terang
@export var intro_fade_in_duration: float = 1.1 # Durasi layar gelap membuka ke world_7
@export var fade_duration: float = 0.8 # Durasi fade out & fade in saat kemunculan Enggang
@export var black_screen_hold_duration: float = 1.1 # Jeda layar hitam penuh saat SFX sayap berbunyi

@export_group("Cutscene Audio SFX")
@export var footstep_sfx: AudioStream # Drag file audio langkah kaki ke sini lewat Inspector
@export var footstep_interval: float = 0.36 # Jeda antar bunyi langkah kaki (detik)
@export var wing_flap_sfx: AudioStream # Drag file audio kepakan sayap Enggang ke sini lewat Inspector

@onready var player: CharacterBody2D = $Player
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var npc_enggang: Node2D = $NPC_Enggang
@onready var enggang_dialogue_pivot: Marker2D = $NPC_Enggang/DialoguePivot

var has_played_cutscene: bool = false
var has_spawned_feathers: bool = false


func _ready() -> void:
	# Posisikan Player di SpawnPoint + tambahan jarak ke kanan
	if spawn_point and player:
		player.global_position = spawn_point.global_position + Vector2(extra_start_offset_right, 0.0)
	elif player:
		player.global_position.x += extra_start_offset_right

	# Sembunyikan NPC_Enggang di awal sebelum fade
	if npc_enggang:
		npc_enggang.visible = false

	# Jalankan cutscene otomatis jika quest_hotel_2 sudah selesai
	var q2_done: bool = (QuestManager and QuestManager.get_quest_status("quest_hotel_2") == "COMPLETED") or GameState.hotel_quest_stage >= 5
	if q2_done and not has_played_cutscene:
		has_played_cutscene = true
		call_deferred("_start_world_7_cutscene")
	elif SceneTransition and SceneTransition.has_method("fade_in"):
		SceneTransition.fade_in()


func _start_world_7_cutscene() -> void:
	if not is_instance_valid(player):
		return

	# 1. Kunci kontrol pemain sejak frame pertama
	if player.has_method("disable_movement"):
		player.disable_movement()
	elif "can_move" in player:
		player.can_move = false
	player.velocity = Vector2.ZERO

	# 2. Ambil layar hitam persisten dari root (jika pindah dari npc_hotel), atau buat baru jika test langsung di world_7
	var intro_layer: CanvasLayer = null
	var intro_black: ColorRect = null

	if get_tree().root.has_meta("hotel_to_world7_fade"):
		intro_layer = get_tree().root.get_meta("hotel_to_world7_fade") as CanvasLayer
		get_tree().root.remove_meta("hotel_to_world7_fade")
		if is_instance_valid(intro_layer) and intro_layer.get_child_count() > 0:
			intro_black = intro_layer.get_child(0) as ColorRect

	if not is_instance_valid(intro_layer) or not is_instance_valid(intro_black):
		intro_layer = CanvasLayer.new()
		intro_layer.layer = 100
		add_child(intro_layer)

		intro_black = ColorRect.new()
		intro_black.color = Color(0, 0, 0, 1.0)
		intro_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		intro_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		intro_layer.add_child(intro_black)

	# Putar suara langkah kaki berulang selama layar masih hitam
	var elapsed_black: float = 0.0
	var step_timer_black: float = 0.0
	while elapsed_black < intro_black_steps_duration:
		var dt: float = get_process_delta_time()
		elapsed_black += dt
		step_timer_black -= dt
		if step_timer_black <= 0.0:
			_play_sfx(footstep_sfx)
			step_timer_black = footstep_interval
		await get_tree().process_frame

	# 3. Mulai auto-walk Danum ke kiri bersamaan dengan fade-in layar yang pelan
	var target_x: float = player.global_position.x - 180.0
	if is_instance_valid(npc_enggang):
		target_x = npc_enggang.global_position.x + stop_distance_from_enggang

	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(intro_black, "color:a", 0.0, intro_fade_in_duration)
	fade_in_tween.finished.connect(intro_layer.queue_free)

	await _auto_walk_left_to(target_x)

	# 4. Fade layar ke hitam untuk kemunculan Enggang
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 15
	add_child(fade_layer)

	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "color:a", 1.0, fade_duration)
	await tween_out.finished

	# 5. Putar SFX kepakan sayap & munculkan NPC_Enggang di tengah layar hitam
	_play_sfx(wing_flap_sfx)

	if is_instance_valid(npc_enggang):
		npc_enggang.visible = true

	var player_anim := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if player_anim:
		player_anim.flip_h = true # Menghadap ke kiri (ke arah NPC_Enggang)

	await get_tree().create_timer(black_screen_hold_duration).timeout

	# 6. Langsung munculkan hujan bulu rontok SEKALI bersamaan dengan layar fade-in
	if is_instance_valid(npc_enggang) and not has_spawned_feathers:
		has_spawned_feathers = true
		_spawn_feather_shower(npc_enggang.global_position)

	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	await tween_in.finished

	fade_layer.queue_free()

	# 7. Setelah layar terang, geser kamera secara terlihat dari MC (Danum) agak ke kiri ke arah Enggang
	var player_cam := _find_camera(player)
	var orig_cam_offset_x: float = 0.0
	if is_instance_valid(player_cam):
		orig_cam_offset_x = player_cam.offset.x
		var pan_left := create_tween()
		pan_left.tween_property(player_cam, "offset:x", orig_cam_offset_x - camera_pan_left_offset, camera_pan_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await pan_left.finished

	# 8. Jalankan dialog Danum & Enggang menggunakan DialoguePivot
	await _play_enggang_dialogue()

	# 9. Fade layar ke hitam persisten (menempel di root agar tidak berkedip saat pindah scene)
	var out_layer := CanvasLayer.new()
	out_layer.layer = 100
	get_tree().root.add_child(out_layer)
	get_tree().root.set_meta("world7_to_world8_fade", out_layer)

	var out_black := ColorRect.new()
	out_black.color = Color(0, 0, 0, 0.0)
	out_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	out_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_layer.add_child(out_black)

	var tween_end := create_tween()
	tween_end.tween_property(out_black, "color:a", 1.0, fade_duration)
	await tween_end.finished

	# 10. Putar 3 kali SFX kepakan sayap di tengah layar hitam
	for i in range(3):
		_play_sfx(wing_flap_sfx)
		await get_tree().create_timer(0.65).timeout

	# 11. Pindah ke world_8.tscn (layar masih hitam pekat)
	get_tree().change_scene_to_file("res://scene/World/world_8.tscn")


# --- FUNGSI SPAWNER HUJAN BULU RONTOK ---
func _spawn_feather_shower(spawn_pos: Vector2) -> void:
	var feather_texture := preload("res://assets/animation/Bulu.png")

	for i in range(15):
		var feather := Sprite2D.new()
		feather.texture = feather_texture
		feather.z_index = 15

		# Geser lebih ke kanan (area sayap/dada Enggang) dan agak ke bawah
		var offset_x := randf_range(-25.0, 85.0)
		var offset_y := randf_range(-65.0, 10.0)
		feather.global_position = spawn_pos + Vector2(offset_x, offset_y)

		var random_scale := randf_range(0.5, 1.0)
		feather.scale = Vector2(random_scale, random_scale)

		feather.flip_h = randf() > 0.5
		feather.flip_v = randf() > 0.5
		add_child(feather)

		var fall_duration := randf_range(1.6, 2.8)

		var target_x := feather.global_position.x + randf_range(-25.0, 25.0)
		var target_y := feather.global_position.y + randf_range(110.0, 175.0)

		var tween := create_tween().set_parallel(true)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(feather, "global_position:y", target_y, fall_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(feather, "global_position:x", target_x, fall_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(feather, "rotation", randf_range(-3.0, 3.0), fall_duration)
		tween.tween_property(feather, "modulate:a", 0.0, fall_duration).set_delay(fall_duration * 0.5)

		tween.chain().tween_callback(feather.queue_free)


func _find_camera(target_player: Node2D) -> Camera2D:
	if is_instance_valid(target_player):
		var cam := target_player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			return cam
	return get_viewport().get_camera_2d()


func _play_sfx(stream: AudioStream) -> void:
	if not stream:
		return
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = stream
	sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)


func _auto_walk_left_to(target_x: float) -> void:
	if not is_instance_valid(player):
		return

	player.set_physics_process(false)

	var player_anim := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(player_anim):
		player_anim.flip_h = true
	if player.has_method("play_cutscene_walk"):
		player.play_cutscene_walk()
	elif is_instance_valid(player_anim):
		player_anim.play("walk")

	var elapsed: float = 0.0
	var step_timer: float = 0.0
	while is_instance_valid(player) and player.global_position.x > target_x and elapsed < 10.0:
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		step_timer -= delta

		if step_timer <= 0.0:
			_play_sfx(footstep_sfx)
			step_timer = footstep_interval

		player.velocity = Vector2(-auto_walk_speed, 0.0)
		player.move_and_slide()
		await get_tree().physics_frame

	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		if player.has_method("play_cutscene_idle"):
			player.play_cutscene_idle()
		elif is_instance_valid(player_anim):
			player_anim.play("default")
		player.set_physics_process(true)


func _play_enggang_dialogue() -> void:
	var p := _get_player_pivot()
	var e: Node2D = enggang_dialogue_pivot if is_instance_valid(enggang_dialogue_pivot) else npc_enggang

	await _say(["Enggang, sekarang aku mengerti.", "Selama ini aku hanya berpikir bahwa menjaga hutan berarti melindunginya dari manusia."], p)
	await _say(["Dan sekarang?"], e)
	await _say(["Aku sadar manusia juga membutuhkan hutan untuk hidup.", "Kita hanya perlu belajar bagaimana memanfaatkannya tanpa merusaknya."], p)
	await _say(["Kamu sudah menemukan jawaban yang kamu cari, Danum.", "Namun, masih ada satu hal yang harus kamu ingat."], e)
	await _say(["Apa itu?"], p)
	await _say([
		"Tidak semua tempat memiliki keadaan dan kebutuhan yang sama.",
		"Apa yang berhasil di sini belum tentu bisa diterapkan begitu saja di tempatmu.",
		"Kamu harus belajar memahami masyarakat dan hutanmu sendiri."
	], e)
	await _say(["Aku mengerti! Aku akan berusaha agar masyarakat dan hutanku bisa kembali pulih seperti dulu lagi."], p)
	await _say(["Kalau begitu, sudah waktunya kita pulang."], e)


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


func _get_player_pivot() -> Node2D:
	if is_instance_valid(player):
		var custom_pivot := player.get_node_or_null("DialoguePivot") as Node2D
		if custom_pivot:
			return custom_pivot
		return player
	return self
