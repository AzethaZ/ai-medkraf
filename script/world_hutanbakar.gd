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
@onready var parallax_2d: Parallax2D = $Parallax2D
@onready var player: Player = $Player
@onready var npc_chaser: Node2D = find_child("NPC_Chaser", true, false)
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

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


func _ready() -> void:
	# 1. Sembunyikan UI yang tidak dipakai
	if game_over_panel:
		game_over_panel.visible = false
	if has_node("ChaseUI/QTECircle"):
		get_node("ChaseUI/QTECircle").visible = false

	# 2. Hubungkan tombol Retry
	if retry_button and not retry_button.pressed.is_connected(_on_retry_button_pressed):
		retry_button.pressed.connect(_on_retry_button_pressed)

	# 3. Kunci Posisi Kamera
	if camera_2d:
		camera_2d.top_level = true
		camera_2d.global_position = Vector2(0, -85)

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

	if parallax_2d:
		parallax_2d.autoscroll.x = 0

	# 5. Fade In Layar
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	await get_tree().create_timer(0.6).timeout
	await start_pre_chase_dialogue()
	start_chase_sequence()


func _process(delta: float) -> void:
	if not is_scene_initialized or not is_chasing:
		return

	# Cek apakah pemain menekan tombol KANAN (D / Panah Kanan / ui_right)
	var is_holding_right = Input.is_action_pressed("ui_right")

	if is_holding_right:
		# 1. Menekan kanan: Background bergerak, Pengejar tertahan/mundur ke jarak aman
		if parallax_2d:
			parallax_2d.autoscroll.x = -scroll_speed
		
		if npc_chaser and npc_chaser.global_position.x > npc_start_x:
			npc_chaser.global_position.x = move_toward(npc_chaser.global_position.x, npc_start_x, chaser_catch_speed * 0.5 * delta)
	else:
		# 2. Dilepas: Background berhenti, NPC Pengejar Maju Menangkap Danum
		if parallax_2d:
			parallax_2d.autoscroll.x = 0
		
		if npc_chaser and player:
			npc_chaser.global_position.x += chaser_catch_speed * delta
			# Pengejar menyentuh Danum -> Game Over
			if npc_chaser.global_position.x >= player.global_position.x - 20:
				trigger_game_over()

	# Kunci koordinat X Danum agar tetap di posisi semula
	if player:
		player.global_position.x = player_start_x


func start_pre_chase_dialogue() -> void:
	if npc_chaser and npc_chaser.has_method("show_chase_dialogue"):
		await npc_chaser.show_chase_dialogue("Kau tidak akan bisa lari, Danum!")
	else:
		await get_tree().create_timer(1.0).timeout


func start_chase_sequence() -> void:
	is_chasing = true
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

	# Trenggiling hanya muncul saat pemain menahan tombol Kanan
	if Input.is_action_pressed("ui_right"):
		if current_cleared >= total_obstacles:
			if obstacle_timer:
				obstacle_timer.stop()
			finish_chase_sequence()
			return

		spawn_obstacle(400.0)
		current_cleared += 1


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

	if parallax_2d:
		parallax_2d.autoscroll.x = 0

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

	if "is_chasing_mode" in player:
		player.is_chasing_mode = false

	# Kembalikan ketinggian lompat Danum ke normal (-400.0) untuk scene selanjutnya
	if player:
		player.JUMP_VELOCITY = -400.0
		var dash_tween = create_tween()
		dash_tween.tween_property(player, "global_position:x", 500.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await dash_tween.finished

	if parallax_2d:
		parallax_2d.autoscroll.x = 0

	var target_scene_path = "res://scene/World/world_sembunyi.tscn"
	if not ResourceLoader.exists(target_scene_path):
		target_scene_path = "res://scene/world_sembunyi.tscn"

	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()

	get_tree().change_scene_to_file(target_scene_path)
