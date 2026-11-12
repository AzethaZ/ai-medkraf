extends Node2D


# --- EXPORT SETTINGS ---
@export var total_obstacles: int = 5         # Total trenggiling yang harus dilewati
@export var max_miss_allowed: int = 2        # Maksimal kena trenggiling sebelum Game Over
@export var scroll_speed: float = 200.0      # Kecepatan lari background
@export var spawn_interval: float = 3.0      # Jeda waktu (detik) antar trenggiling
@export var chaser_catch_speed: float = 120.0 # Kecepatan pengejar mendekat saat Danum diam

# Ketinggian lompat khusus chase scene (bisa diatur langsung via Inspector)
@export var chase_jump_velocity: float = -320.0

@export var obstacle_scene: PackedScene = preload("res://scene/obstacle_spikes.tscn")


# --- REFERENSI NODE ---
@onready var parallax_2d: Parallax2D = get_node_or_null("Parallax2D") as Parallax2D
@onready var parallax_2d2: Parallax2D = (get_node_or_null("Parallax2D2") if has_node("Parallax2D2") else get_node_or_null("Parallax2d2")) as Parallax2D
@onready var parallax_2d3: Parallax2D = (get_node_or_null("Parallax2D3") if has_node("Parallax2D3") else get_node_or_null("Parallax2d3")) as Parallax2D
@onready var parallax_2d4: Parallax2D = (get_node_or_null("Parallax2D4") if has_node("Parallax2D4") else get_node_or_null("Parallax2d4")) as Parallax2D
@onready var parallax_2d5: Parallax2D = (get_node_or_null("Parallax2D5") if has_node("Parallax2D5") else get_node_or_null("Parallax2d5")) as Parallax2D
@onready var parallax_2d6: Parallax2D = (get_node_or_null("Parallax2D6") if has_node("Parallax2D6") else get_node_or_null("Parallax2d6")) as Parallax2D

@onready var player: Player = $Player
@onready var npc_chaser: Node2D = find_child("NPC_Chaser", true, false)
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

# Referensi Audio Node
@onready var chaser_sfx_player: AudioStreamPlayer = $ChaserSFXPlayer if has_node("ChaserSFXPlayer") else null
@onready var chase_bgm_player: AudioStreamPlayer = $ChaseBGMPlayer if has_node("ChaseBGMPlayer") else null

# UI Game Over
@onready var game_over_panel: Control = $ChaseUI/GameOverPanel if has_node("ChaseUI/GameOverPanel") else null
@onready var retry_button: Button = find_child("RetryButton", true, false) as Button


# --- VARIABEL STATE ---
var current_cleared: int = 0
var current_miss_count: int = 0
var is_chasing: bool = false
var is_scene_initialized: bool = false

var player_start_x: float = 0.0
var player_ground_y: float = 0.0 # Posisi Y lantai disembunyikan agar obstacle tidak melayang
var npc_start_x: float = 0.0
var obstacle_timer: Timer
var spawned_obstacles_count: int = 0 # Tambahkan variabel ini di atas (dekat total_obstacles)

func _ready() -> void:
	# 1. Sembunyikan UI yang tidak dipakai
	if game_over_panel:
		game_over_panel.visible = false
	if has_node("ChaseUI/QTECircle"):
		get_node("ChaseUI/QTECircle").visible = false

	# 2. Hubungkan tombol Retry
	if retry_button and not retry_button.pressed.is_connected(_on_retry_button_pressed):
		retry_button.pressed.connect(_on_retry_button_pressed)

	# 3. Kunci Posisi Kamera di Awal (Zoom lebih dekat & posisi lebih ke bawah ke arah MC)
	if camera_2d:
		camera_2d.top_level = true
		# Geser angka Y menjadi lebih kecil (misalnya dari -85 ke -50 atau -40) agar kamera menyorot lebih ke bawah
		camera_2d.global_position = Vector2(player.global_position.x, player.global_position.y -30) 
		camera_2d.zoom = Vector2(2.1, 2.1) # Atur tingkat zoom-in di sini (makin besar makin dekat)

	# 4. Simpan koordinat awal & Override JUMP_VELOCITY player sejak awal scene dimuat
	if player:
		player_start_x = player.global_position.x
		player_ground_y = player.global_position.y # Simpan koordinat tanah asli Danum
		player.JUMP_VELOCITY = chase_jump_velocity
		if "is_chasing_mode" in player:
			player.is_chasing_mode = true

	if npc_chaser:
		npc_start_x = npc_chaser.global_position.x

	is_scene_initialized = true

	# Reset autoscroll keempat layer paralaks saat scene dimuat
	_stop_all_parallax()

	# 5. Fade In Layar
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	await get_tree().create_timer(0.6).timeout
	await start_pre_chase_dialogue()
	start_chase_sequence()


func _process(delta: float) -> void:
	if not is_scene_initialized or not is_chasing:
		return

	# 1. Background Parallax OTOMATIS BERGERAK (Auto-Run)
	if parallax_2d:
		parallax_2d.autoscroll.x = -scroll_speed * 1.0
	if parallax_2d2:
		parallax_2d2.autoscroll.x = -scroll_speed * 0.75
	if parallax_2d3:
		parallax_2d3.autoscroll.x = -scroll_speed * 0.50
	if parallax_2d4:
		parallax_2d4.autoscroll.x = -scroll_speed * 0.25
	if parallax_2d5:
		parallax_2d5.autoscroll.x = -scroll_speed * 0.30# Sesuaikan pengali kecepatannya
	if parallax_2d6:
		parallax_2d6.autoscroll.x = -scroll_speed * 1.5# Sesuaikan pengali kecepatannya

	# 2. Posisi NPC Chaser
	if npc_chaser and npc_chaser.global_position.x > npc_start_x:
		npc_chaser.global_position.x = move_toward(npc_chaser.global_position.x, npc_start_x, chaser_catch_speed * delta)

	# 3. Kunci koordinat X Danum & PAKSA ANIMASI BERLARI (Aman dari frame reset)
	if player:
		player.global_position.x = player_start_x
		
		# Jika Danum di atas tanah, pastikan animasi lari diputar (hanya dipanggil jika belum aktif)
		if player.is_on_floor() and player.has_node("AnimatedSprite2D"):
			var anim = player.get_node("AnimatedSprite2D")
			# Gunakan 'not anim.is_playing()' atau cek namanya agar tidak di-play ulang terus di setiap frame
			if anim.animation != "run" and anim.animation != "walk":
				if anim.sprite_frames.has_animation("run"):
					anim.play("run")
				else:
					anim.play("walk")
			elif not anim.is_playing():
				anim.play() # Melanjutkan pemutaran animasi jika sempat berhenti


func start_pre_chase_dialogue() -> void:
	# Putar SFX marah Chaser tepat saat dialog dipicu
	if chaser_sfx_player and chaser_sfx_player.stream:
		chaser_sfx_player.play()

	if npc_chaser and npc_chaser.has_method("show_chase_dialogue"):
		await npc_chaser.show_chase_dialogue("Kau tidak akan bisa lari, Danum!")
	else:
		await get_tree().create_timer(1.0).timeout


func start_chase_sequence() -> void:
	is_chasing = true
	current_cleared = 0
	spawned_obstacles_count = 0 # Reset hitungan awal
	
	if player:
		# 1. Aktifkan auto-walk ke kanan
		if player.has_method("start_auto_walk"):
			player.start_auto_walk(1.0)
			
		# 2. Aktifkan flag mode kejar-kejaran agar animasi lari aktif
		if "is_chasing_mode" in player:
			player.is_chasing_mode = true
			
		# 3. Paksa putar animasi lari
		if player.has_node("AnimatedSprite2D"):
			var anim = player.get_node("AnimatedSprite2D")
			if anim.sprite_frames.has_animation("run"):
				anim.play("run")
			else:
				anim.play("walk")

	# 4. TRANSISI KAMERA: Zoom-out halus dari dekat ke ukuran normal (1.0, 1.0)
	if camera_2d:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(camera_2d, "zoom", Vector2(1.0, 1.0), 0.8)
		tween.tween_property(camera_2d, "global_position:y", -85, 0.8)

	# 5. Putar Musik BGM Pengejaran
	if chase_bgm_player and chase_bgm_player.stream and not chase_bgm_player.playing:
		chase_bgm_player.play()
		
	# 6. Jalankan spawner rintangan (Hanya dipanggil SEKALI di sini)
	start_obstacle_spawner()


func start_obstacle_spawner() -> void:
	obstacle_timer = Timer.new()
	obstacle_timer.wait_time = spawn_interval
	obstacle_timer.one_shot = false
	obstacle_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(obstacle_timer)
	obstacle_timer.start()


func _on_spawn_timer_timeout() -> void:
	if not is_chasing:
		return

	# Tambah hitungan obstacle yang sudah di-spawn
	spawned_obstacles_count += 1
	spawn_obstacle(400.0)

	# Jika sudah mencapai Total Obstacles (7), matikan timer agar tidak spawn lagi
	if spawned_obstacles_count >= total_obstacles:
		if obstacle_timer:
			obstacle_timer.stop()
			obstacle_timer.queue_free()


func spawn_obstacle(spawn_x: float) -> void:
	if not obstacle_scene:
		return

	var obstacle = obstacle_scene.instantiate() as Node2D
	add_child(obstacle)

	# Selalu gunakan player_ground_y agar trenggiling menempel di tanah (tidak ikut posisi Y saat melompat)
	obstacle.global_position = Vector2(spawn_x, player_ground_y)

	if "move_speed" in obstacle:
		obstacle.move_speed = scroll_speed


func on_player_hit_obstacle() -> void:
	current_miss_count += 1
	play_hit_effect()
	
	# PENTING: Saat menabrak rintangan, anggap rintangan tersebut sudah "selesai dilewati" 
	# agar target total_obstacles (7 buah) tetap tercapai dan game bisa finish!
	if is_chasing:
		current_cleared += 1
		print("Obstacle ditabrak/dilewati: ", current_cleared)
		
		if current_cleared >= total_obstacles:
			is_chasing = false
			if obstacle_timer:
				obstacle_timer.stop()
				obstacle_timer.queue_free()
			finish_chase_sequence()
			return

	if current_miss_count >= max_miss_allowed:
		trigger_game_over()


func play_hit_effect() -> void:
	if not player:
		return

	var tween = create_tween()
	tween.tween_property(player, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(player, "modulate", Color(1, 1, 1, 1), 0.1)

	if camera_2d:
		var cam_tween = create_tween()
		cam_tween.tween_property(camera_2d, "global_position", Vector2(4, -81), 0.05)
		cam_tween.tween_property(camera_2d, "global_position", Vector2(0, -85), 0.05)


func trigger_game_over() -> void:
	is_chasing = false
	if obstacle_timer:
		obstacle_timer.stop()

	# Hentikan semua paralaks & Musik BGM saat Game Over
	_stop_all_parallax()
	if chase_bgm_player and chase_bgm_player.playing:
		chase_bgm_player.stop()

	if "is_chasing_mode" in player:
		player.is_chasing_mode = false

	if game_over_panel:
		game_over_panel.visible = true


func _on_retry_button_pressed() -> void:
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
	get_tree().reload_current_scene()


func finish_chase_sequence() -> void:
	is_chasing = false
	if obstacle_timer:
		obstacle_timer.stop()
		obstacle_timer.queue_free()
		
	if "is_chasing_mode" in player:
		player.is_chasing_mode = false
		
	# Kembalikan ketinggian lompat Danum ke normal (-400.0) untuk scene selanjutnya
	if player:
		player.JUMP_VELOCITY = -400.0
		if player.has_method("disable_movement"):
			player.disable_movement()
			
	# Hentikan autoscroll semua paralaks
	_stop_all_parallax()
	
	var target_scene_path = "res://scene/World/world_sembunyi.tscn"
	if not ResourceLoader.exists(target_scene_path):
		target_scene_path = "res://scene/World/world_sembunyi.tscn"
		
	# 1. Layar berubah menjadi hitam (Fade Out)
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
	
	# Beri jeda singkat agar layar benar-benar gelap sempurna dulu
	await get_tree().create_timer(0.4).timeout
	
	# 2. Tampilkan dialog monolog Danum
	var dialog_text = "Aku harus mencari tempat sembunyi..."
	if DialogueManager:
		if DialogueManager.has_method("start_dialogue"):
			DialogueManager.start_dialogue([dialog_text], player)
			
			# Pindahkan posisi kotak dialog ke tengah layar agar tidak ikut karakter
			if DialogueManager.has_method("set_dialogue_centered"):
				DialogueManager.set_dialogue_centered()
				
		# Tunggu sampai pemain selesai membaca/berinteraksi dengan dialog
		if DialogueManager.has_signal("dialogue_finished"):
			await DialogueManager.dialogue_finished
		elif DialogueManager.has_signal("finished"):
			await DialogueManager.finished
		else:
			while DialogueManager.get("is_dialogue_active") == true:
				await get_tree().process_frame
	else:
		await get_tree().create_timer(3.5).timeout
	
	# 3. Setelah pemain selesai berinteraksi dengan dialognya, baru pindah ke scene berikutnya
	get_tree().change_scene_to_file(target_scene_path)
	

# Helper function untuk menghentikan semua autoscroll paralaks secara bersamaan
func _stop_all_parallax() -> void:
	if parallax_2d:
		parallax_2d.autoscroll.x = 0
	if parallax_2d2:
		parallax_2d2.autoscroll.x = 0
	if parallax_2d3:
		parallax_2d3.autoscroll.x = 0
	if parallax_2d4:
		parallax_2d4.autoscroll.x = 0
	if parallax_2d5:
		parallax_2d5.autoscroll = Vector2.ZERO
	if parallax_2d6:
		parallax_2d6.autoscroll = Vector2.ZERO

func increment_obstacle_cleared() -> void:
	if not is_chasing:
		return
		
	current_cleared += 1
	print("Obstacle dilewati: ", current_cleared)
	
	# Jika sudah mencapai atau melebihi target Total Obstacles (7 buah)
	if current_cleared >= total_obstacles:
		is_chasing = false # Matikan status chase agar spawner menolak spawn baru
		
		if obstacle_timer:
			obstacle_timer.stop() # Hentikan timer agar tidak spawn lagi
			obstacle_timer.queue_free() # Hapus node timer dari memori
			
		finish_chase_sequence()
