extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false) as Camera2D
@onready var enggang: Node2D = find_child("NPC_Enggang", true, false) as Node2D
@onready var wing_flap_sfx: AudioStreamPlayer = get_node_or_null("WingFlapSFX")

@export var intro_black_duration: float = 2.0
@export var intro_fade_duration: float = 1.5

# Array percakapan cutscene intro world_2
var intro_dialogues = [
	{"speaker_name": "Enggang", "text": "Selamat datang di pedalaman hutan Tiongkok, Danum. Dari sini lah kamu akan mulai pelajaran pertama."},
	{"speaker_name": "Danum", "text": "Woaahh...banyak sekali pohon aku hampir tidak bisa melihat hal lain selain hutan yang lebat."},
	{"speaker_name": "Enggang", "text": "Hahaha, di sini masih terdapat hal lain yang akan membuatmu lebih terkesan Danum."},
	{"speaker_name": "Danum", "text": "Apa itu Enggang? aku penasaran sekali!"},
	{"speaker_name": "Enggang", "text": "Nanti kamu akan segera mengetahuinya begitu menjejakkan kaki di sana."},
	{"speaker_name": "Danum", "text": "Baiklah Enggang, aku sudah tidak sabar."},
	{"speaker_name": "Enggang", "text": "Hahaha, aku suka semangatmu Danum. Yasudah mulai dari sini aku akan mengawasimu dari jauh."}
]

var default_zoom: Vector2 = Vector2(1.0, 1.0)
var cutscene_zoom: Vector2 = Vector2(1.4, 1.4)

var default_offset: Vector2 = Vector2.ZERO
var cutscene_offset: Vector2 = Vector2(90, 20)

func _ready() -> void:
	# Ubah warna hanya pada AnimatedSprite2D milik Player khusus di world_2
	var player_node := get_node_or_null("Player")
	if player_node and player_node.has_node("AnimatedSprite2D"):
		var player_sprite: AnimatedSprite2D = player_node.get_node("AnimatedSprite2D")
		player_sprite.modulate = Color(0.92, 0.84, 1.0, 1.0) # Sesuaikan tint ungu/senja world_2
	# 0. MEMUTAR AUDIO DUNIA
	var ambience_file = preload("res://assets/audio/chinese_ambience.mp3")
	var bgm_file = preload("res://assets/audio/chinese_music2.mp3")
	
	if MusicManager:
		MusicManager.play_world_audio(ambience_file, bgm_file, 6.0, -12.0)
		
	# 1. AMBIL SPAWN POINT TARGET DARI TRANSITION SYSTEM
	var spawn_name: String = "SpawnPoint"
	if SceneTransition and "target_spawn_id" in SceneTransition and SceneTransition.target_spawn_id != "":
		spawn_name = SceneTransition.target_spawn_id
		SceneTransition.target_spawn_id = ""
		
	_move_player_to_spawn(spawn_name)
	
	# 2. Setup Kamera Ruangan
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()
		camera_2d.limit_left = -1105
		camera_2d.limit_right = 865
		camera_2d.limit_top = -290
		default_zoom = camera_2d.zoom
		default_offset = camera_2d.offset
		
	# 3. CEK APAKAH CUTSCENE SUDAH PERNAH DIMAINKAN
	var already_played: bool = false
	if "cutscene_world_2_done" in GameState:
		already_played = GameState.cutscene_world_2_done
	elif "cutscene_world_2_done" in QuestManager:
		already_played = QuestManager.cutscene_world_2_done
		
	if already_played:
		if enggang:
			enggang.queue_free()
			
		if SceneTransition and SceneTransition.has_method("fade_in"):
			await SceneTransition.fade_in()
			
		if player and player.has_method("enable_movement"):
			player.enable_movement()
	else:
		if player and player.has_method("disable_movement"):
			player.disable_movement()
			
		if camera_2d:
			camera_2d.zoom = cutscene_zoom
			camera_2d.offset = cutscene_offset
			
		# Tunggu layar hitam 2 detik + suara sayap + fade in + hujan bulu selesai sebelum dialog mulai
		await _play_world_entry_transition()
		
		# Jalankan dialog intro setelah tirai hitam benar-benar terbuka
		await run_intro_cutscene()
		
		if "cutscene_world_2_done" in GameState:
			GameState.cutscene_world_2_done = true
		elif "cutscene_world_2_done" in QuestManager:
			QuestManager.cutscene_world_2_done = true
			
		if player and player.has_method("enable_movement"):
			player.enable_movement()

func _play_world_entry_transition() -> void:
	# 1. Tutup layar penuh dengan tirai hitam sejak frame pertama
	var black_layer := CanvasLayer.new()
	black_layer.layer = 100
	var black_rect := ColorRect.new()
	black_rect.color = Color.BLACK
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_layer.add_child(black_rect)
	add_child(black_layer)
	
	# 2. Putar suara kepakan sayap selama 2 detik layar hitam
	_trigger_wing_flap()
	await get_tree().create_timer(1.0, true).timeout
	_trigger_wing_flap()
	await get_tree().create_timer(max(0.0, intro_black_duration - 1.0), true).timeout
	
	# 3. Mulai buka tirai hitam + munculkan hujan bulu yang sama persis seperti saat Enggang keluar
	var fade_tween := create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_property(black_rect, "modulate:a", 0.0, intro_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if SceneTransition and SceneTransition.has_method("fade_in"):
		SceneTransition.fade_in()
		
	var feather_origin: Vector2 = enggang.global_position if enggang else (player.global_position if player else Vector2.ZERO)
	spawn_feather_shower(feather_origin)
	
	await fade_tween.finished
	black_layer.queue_free()
	
	# Jeda singkat agar bulu sempat terlihat melayang turun sebelum dialog pertama muncul
	await get_tree().create_timer(0.6, true).timeout

func _trigger_wing_flap() -> void:
	if wing_flap_sfx and wing_flap_sfx.stream:
		wing_flap_sfx.pitch_scale = randf_range(0.95, 1.05)
		wing_flap_sfx.play()
	else:
		play_flying_sound()

func run_intro_cutscene() -> void:
	if not DialogueManager:
		return
		
	var enggang_target: Node2D = enggang
	if enggang and enggang.has_node("DialoguePivot"):
		enggang_target = enggang.get_node("DialoguePivot") as Node2D
		
	for item in intro_dialogues:
		var target_speaker: Node2D = enggang_target if item["speaker_name"] == "Enggang" else player
		
		if DialogueManager.has_method("start_dialogue"):
			await DialogueManager.start_dialogue([item["text"]], target_speaker)
		elif DialogueManager.has_method("show_dialogue"):
			await DialogueManager.show_dialogue([item["text"]], target_speaker)
			
		if DialogueManager.has_signal("dialogue_ended"):
			await DialogueManager.dialogue_ended
		elif DialogueManager.has_signal("dialogue_finished"):
			await DialogueManager.dialogue_finished
			
	# --- EFEK FADE TRANSITION + SUARA KEPAKAN SAYAP + ENGGANG HILANG ---
	if enggang:
		var enggang_position = enggang.global_position
		
		# 1. Fade Out Layar
		if SceneTransition and SceneTransition.has_method("fade_out"):
			await SceneTransition.fade_out()
			
		# 2. Mainkan Suara Burung Terbang / Kepakan Sayap saat layar hitam
		play_flying_sound()
		
		# Jeda saat layar hitam total
		await get_tree().create_timer(0.8).timeout
		
		# 3. Hapus Enggang dan munculkan hujan bulu (15 helai)
		enggang.queue_free()
		spawn_feather_shower(enggang_position)
		
		# 4. Fade In Kembali
		if SceneTransition and SceneTransition.has_method("fade_in"):
			await SceneTransition.fade_in()
			
		# 5. Kamera Zoom Out perlahan
		if camera_2d:
			var tween = create_tween().set_parallel(true)
			tween.tween_property(camera_2d, "zoom", default_zoom, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(camera_2d, "offset", default_offset, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tween.finished

# --- FUNGSI SPAWNER SUARA TERBANG ---
func play_flying_sound() -> void:
	var fly_sfx = preload("res://assets/audio/wing_sound.mp3")
	if HasManagerSound():
		pass
	else:
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.stream = fly_sfx
		sfx_player.volume_db = 0.0
		add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)

func HasManagerSound() -> bool:
	return false

# --- FUNGSI SPAWNER HUJAN BULU RONTOK ---
func spawn_feather_shower(spawn_pos: Vector2) -> void:
	var feather_texture = preload("res://assets/animation/Bulu.png")
	
	for i in range(15):
		var feather = Sprite2D.new()
		feather.texture = feather_texture
		feather.z_index = 10
		
		var offset_x = randf_range(-100, 20)
		var offset_y = randf_range(-100, 30)
		feather.global_position = spawn_pos + Vector2(offset_x, offset_y)
		
		var random_scale = randf_range(0.5, 1.0)
		feather.scale = Vector2(random_scale, random_scale)
		
		feather.flip_h = randf() > 0.5
		feather.flip_v = randf() > 0.5
		add_child(feather)
		
		var fall_duration = randf_range(1.6, 2.8)
		
		var target_x = feather.global_position.x + randf_range(-60, 10)
		var target_y = feather.global_position.y + randf_range(140, 220)
		
		var tween = create_tween().set_parallel(true)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(feather, "global_position:y", target_y, fall_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(feather, "global_position:x", target_x, fall_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(feather, "rotation", randf_range(-3.0, 3.0), fall_duration)
		tween.tween_property(feather, "modulate:a", 0.0, fall_duration).set_delay(fall_duration * 0.5)
		
		tween.chain().tween_callback(feather.queue_free)

# --- FUNGSI HELPER PEMINDAHAN POSISI SPAWN ---
func _move_player_to_spawn(spawn_name: String) -> void:
	var spawn_node = find_child(spawn_name, true, false)
	if spawn_node and player:
		player.global_position = spawn_node.global_position
