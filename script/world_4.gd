extends Node2D

@export var camera_limit_left: int = -1400
@export var camera_limit_right: int = -240
@export var camera_limit_top: int = -290

@export var intro_black_duration: float = 1.0
@export var intro_fade_duration: float = 1.4

@export_group("Exit Guard Settings")
@export var petani_quest_id: String = "quest_kopi_1"
@export var callout_left_margin: float = 165.0 # Jarak bubble panggilan dari tepi kiri layar (makin besar = makin ke kanan)
@export var push_back_distance: float = 42.0 # Jarak Danum berjalan ke kiri menjauhi AreaExit
@export var push_back_duration: float = 0.45 # Durasi langkah jalan ke kiri

const FLYING_SFX = preload("res://assets/audio/wing_sound.mp3")
const VIETNAM_BGM = preload("res://assets/audio/viatnamese_bgm.mp3")

@onready var player: Node2D = $Player
@onready var wing_flap_sfx: AudioStreamPlayer = get_node_or_null("WingFlapSFX")
@onready var area_exit: Area2D = get_node_or_null("AreaExit")
@onready var npc_petani: Node2D = get_node_or_null("npc_petani")

var is_exit_warning_active: bool = false


func _ready() -> void:
	# 1. Putar / lanjutkan musik latar Vietnam tanpa me-restart jika sudah jalan
	if MusicManager:
		var is_already_playing_vietnam: bool = (
			MusicManager.bgm_player
			and MusicManager.bgm_player.playing
			and MusicManager.bgm_player.stream == VIETNAM_BGM
		)
		if not is_already_playing_vietnam:
			if MusicManager.has_method("play_world_audio"):
				MusicManager.play_world_audio(null, VIETNAM_BGM, -0.5, -9.0)
			elif MusicManager.has_method("play_world_music"):
				MusicManager.play_world_music("world_4")

	# 2. Cek apakah ini pertama kali masuk world_4
	var sudah_masuk_world4: bool = false
	if GameState and GameState.has_meta("world_4_entry_played"):
		sudah_masuk_world4 = bool(GameState.get_meta("world_4_entry_played"))

	# 3. Posisikan Player di Spawn1 jika pertama kali masuk, atau di target_spawn_id SceneTransition jika sudah pernah
	var spawn_name: String = "SpawnPoint"
	if SceneTransition and "target_spawn_id" in SceneTransition and SceneTransition.target_spawn_id != "":
		spawn_name = SceneTransition.target_spawn_id
		SceneTransition.target_spawn_id = ""
	elif not sudah_masuk_world4:
		spawn_name = "Spawn1"

	_move_player_to_spawn(spawn_name)

	# 4. Atur batas kamera world_4
	var cam: Camera2D = _find_camera(player)
	if cam:
		cam.enabled = true
		cam.make_current()
		cam.limit_left = camera_limit_left
		cam.limit_right = camera_limit_right
		cam.limit_top = camera_limit_top

	# 5. Sambungkan deteksi AreaExit agar tidak bisa ke world_5 sebelum bicara dengan npc_petani
	if area_exit and not area_exit.body_entered.is_connected(_on_area_exit_body_entered):
		area_exit.body_entered.connect(_on_area_exit_body_entered)

	# 6. Jalankan efek transisi masuk (layar hitam -> kepakan sayap -> hujan bulu di Spawn1)
	if not sudah_masuk_world4:
		if GameState:
			GameState.set_meta("world_4_entry_played", true)

		if player and player.has_method("disable_movement"):
			player.disable_movement()

		await _play_world_entry_transition()

		if player and player.has_method("enable_movement"):
			player.enable_movement()
	else:
		if SceneTransition and SceneTransition.has_method("fade_in"):
			await SceneTransition.fade_in()


# --- PENJAGA AREA EXIT (PANGGILAN DARI POJOK KIRI) ---
func _on_area_exit_body_entered(body: Node2D) -> void:
	if body != player or is_exit_warning_active:
		return

	if _has_talked_to_petani():
		return

	is_exit_warning_active = true
	if player.has_method("disable_movement"):
		player.disable_movement()
	elif "can_move" in player:
		player.can_move = false
	if "velocity" in player:
		player.velocity = Vector2.ZERO

	# Pastikan Danum dalam animasi diam saat menoleh
	_play_player_idle()

	# Buat pivot sementara di sisi kiri layar
	var left_callout_pivot := Node2D.new()
	var cam := get_viewport().get_camera_2d()
	var target_y: float = npc_petani.global_position.y - 45.0 if is_instance_valid(npc_petani) else player.global_position.y - 45.0
	if cam:
		var screen_left_x: float = cam.get_screen_center_position().x - (get_viewport_rect().size.x * 0.5 / cam.zoom.x) + callout_left_margin
		left_callout_pivot.global_position = Vector2(screen_left_x, target_y)
	else:
		left_callout_pivot.global_position = player.global_position + Vector2(-120.0, -45.0)
	add_child(left_callout_pivot)

	# Danum menoleh ke kiri ke arah suara panggilan
	var player_anim := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if player_anim:
		player_anim.flip_h = true

	# Tampilkan bubble dialog panggilan dari kiri
	if DialogueManager:
		DialogueManager.start_dialogue(["Hei, kau mau ke mana, Nak? Kemarilah sebentar!"], left_callout_pivot)
		if "is_active" in DialogueManager:
			while DialogueManager.is_active:
				if not is_inside_tree():
					return
				await get_tree().process_frame
		elif DialogueManager.has_signal("dialogue_finished"):
			await DialogueManager.dialogue_finished
		elif DialogueManager.has_signal("dialogue_ended"):
			await DialogueManager.dialogue_ended

	if not is_inside_tree():
		return
	left_callout_pivot.queue_free()

	# Auto-walk ke kiri menjauhi AreaExit dengan animasi jalan player
	await _auto_walk_player_left()

	if not is_inside_tree():
		return

	if player.has_method("enable_movement"):
		player.enable_movement()
	elif "can_move" in player:
		player.can_move = true

	is_exit_warning_active = false


func _auto_walk_player_left() -> void:
	if not is_instance_valid(player):
		return

	var walk_dir: float = -1.0
	var walk_speed: float = push_back_distance / maxf(push_back_duration, 0.05)

	player.set_physics_process(false)

	var player_anim := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(player_anim):
		player_anim.flip_h = (walk_dir < 0.0)

	if player.has_method("play_cutscene_walk"):
		player.play_cutscene_walk()
	elif is_instance_valid(player_anim):
		player_anim.play("walk")

	var target_x: float = player.global_position.x - push_back_distance
	var elapsed: float = 0.0
	while is_instance_valid(player) and elapsed < push_back_duration:
		if player.global_position.x <= target_x:
			break

		var delta: float = get_physics_process_delta_time()
		elapsed += delta

		if player is CharacterBody2D:
			player.velocity = Vector2(walk_dir * walk_speed, 0.0)
			player.move_and_slide()
		else:
			player.global_position.x += walk_dir * walk_speed * delta

		await get_tree().physics_frame

	if is_instance_valid(player):
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		_play_player_idle()
		player.set_physics_process(true)


func _play_player_idle() -> void:
	if not is_instance_valid(player):
		return
	var player_anim := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if player.has_method("play_cutscene_idle"):
		player.play_cutscene_idle()
	elif is_instance_valid(player_anim):
		player_anim.play("default")


func _has_talked_to_petani() -> bool:
	var target_quest_id: String = petani_quest_id
	if area_exit and "required_quest_id" in area_exit and area_exit.required_quest_id != "":
		target_quest_id = area_exit.required_quest_id

	if target_quest_id != "" and QuestManager and QuestManager.has_method("get_quest_status"):
		var status: String = QuestManager.get_quest_status(target_quest_id)
		if status == "ACTIVE" or status == "IN_PROGRESS" or status == "COMPLETED":
			return true

	return false


func _play_world_entry_transition() -> void:
	var black_layer := CanvasLayer.new()
	black_layer.layer = 100
	var black_rect := ColorRect.new()
	black_rect.color = Color.BLACK
	black_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_layer.add_child(black_rect)
	add_child(black_layer)

	_trigger_wing_flap()
	await get_tree().create_timer(intro_black_duration, true).timeout

	var fade_tween := create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_property(black_rect, "modulate:a", 0.0, intro_fade_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	if SceneTransition and SceneTransition.has_method("fade_in"):
		SceneTransition.fade_in()

	var feather_origin: Vector2 = player.global_position if player else Vector2.ZERO
	spawn_feather_shower(feather_origin)

	await fade_tween.finished
	black_layer.queue_free()


func _trigger_wing_flap() -> void:
	if wing_flap_sfx and wing_flap_sfx.stream:
		wing_flap_sfx.pitch_scale = randf_range(0.95, 1.05)
		wing_flap_sfx.play()
	else:
		play_flying_sound()


func play_flying_sound() -> void:
	var fly_sfx := preload("res://assets/audio/wing_sound.mp3")
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = fly_sfx
	sfx_player.volume_db = -10.0
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)


func spawn_feather_shower(spawn_pos: Vector2) -> void:
	var feather_texture := preload("res://assets/animation/Bulu.png")

	for i in range(15):
		var feather := Sprite2D.new()
		feather.texture = feather_texture
		feather.z_index = 15

		var offset_x := randf_range(-130.0, 20.0)
		var offset_y := randf_range(-150.0, -50.0)
		feather.global_position = spawn_pos + Vector2(offset_x, offset_y)

		var random_scale := randf_range(0.5, 1.0)
		feather.scale = Vector2(random_scale, random_scale)

		feather.flip_h = randf() > 0.5
		feather.flip_v = randf() > 0.5
		add_child(feather)

		var fall_duration := randf_range(1.6, 2.8)

		var target_x := feather.global_position.x + randf_range(-40.0, 40.0)
		var target_y := feather.global_position.y + randf_range(140.0, 200.0)

		var tween := create_tween().set_parallel(true)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(feather, "global_position:y", target_y, fall_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(feather, "global_position:x", target_x, fall_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(feather, "rotation", randf_range(-3.0, 3.0), fall_duration)
		tween.tween_property(feather, "modulate:a", 0.0, fall_duration).set_delay(fall_duration * 0.5)

		tween.chain().tween_callback(feather.queue_free)


func _move_player_to_spawn(spawn_name: String) -> void:
	var spawn_node := find_child(spawn_name, true, false)
	if spawn_node and player:
		player.global_position = spawn_node.global_position


func _find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found:
			return found
	return null
