extends Node2D

@export var qte_target_count: int = 5       # Target sukses 5x QTE
@export var max_miss_allowed: int = 2        # Maksimal 2x tertabrak -> Game Over
@export var scroll_speed: float = 200.0       # Kecepatan lari background & duri

@export var obstacle_scene: PackedScene = preload("res://scene/obstacle_spikes.tscn") # Path scene duri

@onready var parallax_2d: Parallax2D = $Parallax2D
@onready var player: Player = $Player
@onready var npc_chaser: Node2D = find_child("NPC_Chaser", true, false)
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)
@onready var interact_icon: Sprite2D = npc_chaser.find_child("InteractIcon", true, false) if npc_chaser else null

# UI Node QTE
@onready var qte_icon: Control = $ChaseUI/QTECircle
@onready var approach_circle: Control = $ChaseUI/QTECircle/ApproachCircle if has_node("ChaseUI/QTECircle/ApproachCircle") else null
@onready var game_over_panel: Control = $ChaseUI/GameOverPanel
@onready var retry_button: Button = find_child("RetryButton", true, false) as Button

var current_qte_success: int = 0
var current_miss_count: int = 0
var is_chasing: bool = false
var is_qte_active: bool = false
var qte_pressed_in_time: bool = false

var current_qte_id: int = 0
var active_qte_tween: Tween = null

# Variabel posisi X asli dari Editor
var player_start_x: float = 0.0
var npc_start_x: float = 0.0
var is_scene_initialized: bool = false

func _ready() -> void:
	if game_over_panel:
		game_over_panel.visible = false
	if qte_icon:
		qte_icon.visible = false
	if interact_icon:
		interact_icon.visible = false
		
	if retry_button and not retry_button.pressed.is_connected(_on_retry_button_pressed):
		retry_button.pressed.connect(_on_retry_button_pressed)

	if camera_2d:
		camera_2d.top_level = true
		camera_2d.global_position = Vector2(0, -85)

	if player:
		player_start_x = player.global_position.x
		player.global_position.x = player_start_x
	if npc_chaser:
		npc_start_x = npc_chaser.global_position.x
		npc_chaser.global_position.x = npc_start_x

	is_scene_initialized = true

	if parallax_2d:
		parallax_2d.autoscroll.x = 0

	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	if interact_icon:
		interact_icon.visible = true
		await get_tree().create_timer(0.6).timeout
		interact_icon.visible = false

	await start_pre_chase_dialogue()
	start_chase_sequence()

func _process(_delta: float) -> void:
	# Kunci posisi X hanya selama proses kejar-kejaran (is_chasing = true)
	if is_scene_initialized and is_chasing:
		if player:
			player.global_position.x = player_start_x
		if npc_chaser:
			npc_chaser.global_position.x = npc_start_x

func start_pre_chase_dialogue() -> void:
	if npc_chaser and npc_chaser.has_method("show_chase_dialogue"):
		await npc_chaser.show_chase_dialogue("Kau tidak akan bisa lari, Danum!")
	else:
		await get_tree().create_timer(1.0).timeout

func start_chase_sequence() -> void:
	is_chasing = true
	
	if parallax_2d:
		parallax_2d.autoscroll.x = -scroll_speed

	if player and player.has_method("start_auto_walk"):
		player.start_auto_walk(1.5)

	if npc_chaser and npc_chaser.has_method("start_chase"):
		npc_chaser.start_chase()

	await get_tree().create_timer(0.5).timeout
	spawn_next_qte()

func _unhandled_input(event: InputEvent) -> void:
	if is_chasing and is_qte_active and event.is_action_pressed("interact"):
		
		var is_timing_perfect: bool = true
		if approach_circle:
			if approach_circle.scale.x > 1.35:
				is_timing_perfect = false

		qte_pressed_in_time = true
		is_qte_active = false
		
		if active_qte_tween and active_qte_tween.is_running():
			active_qte_tween.kill()

		if qte_icon:
			qte_icon.visible = false
		
		get_viewport().set_input_as_handled()
		
		if is_timing_perfect:
			on_qte_success()
		else:
			on_qte_missed()

func spawn_next_qte() -> void:
	if not is_chasing or not qte_icon:
		return
		
	if current_qte_success >= qte_target_count:
		finish_chase_sequence()
		return

	current_qte_id += 1
	var this_qte_id = current_qte_id

	# Spawn Duri di X = 400.0 (luar kanan layar)
	var obstacle_spawn_x: float = 400.0
	spawn_obstacle(obstacle_spawn_x)
	
	# Hitung Durasi Presisi Tiba Duri berdasarkan jarak
	var player_x: float = player_start_x if player else 0.0
	var travel_distance: float = obstacle_spawn_x - player_x
	var exact_qte_duration: float = travel_distance / scroll_speed
	
	# Randomize Posisi UI QTE
	var viewport_size = get_viewport_rect().size
	var random_x = randf_range(150, viewport_size.x - 150)
	var random_y = randf_range(150, viewport_size.y - 150)
	qte_icon.position = Vector2(random_x, random_y)
	qte_icon.visible = true

	# Animasi Approach Circle Mengecil
	if approach_circle:
		approach_circle.scale = Vector2(2.5, 2.5)
		approach_circle.pivot_offset = approach_circle.size / 2.0
		
		if active_qte_tween and active_qte_tween.is_running():
			active_qte_tween.kill()

		active_qte_tween = create_tween()
		active_qte_tween.tween_property(approach_circle, "scale", Vector2(1.0, 1.0), exact_qte_duration).set_trans(Tween.TRANS_LINEAR)

	is_qte_active = true
	qte_pressed_in_time = false
	
	await get_tree().create_timer(exact_qte_duration).timeout
	
	if is_qte_active and not qte_pressed_in_time and current_qte_id == this_qte_id:
		is_qte_active = false
		qte_icon.visible = false
		on_qte_missed()

func spawn_obstacle(spawn_x: float) -> void:
	if not obstacle_scene:
		return
		
	var obstacle = obstacle_scene.instantiate() as Node2D
	add_child(obstacle)
	
	var ground_y = player.global_position.y if player else 0.0
	obstacle.global_position = Vector2(spawn_x, ground_y)
	
	if "move_speed" in obstacle:
		obstacle.move_speed = scroll_speed

func jump_player() -> void:
	if not player:
		return
		
	var ground_y = player.global_position.y
	var jump_height = 45.0
	
	var tween = create_tween()
	tween.tween_property(player, "global_position:y", ground_y - jump_height, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "global_position:y", ground_y, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func on_qte_success() -> void:
	current_qte_success += 1
	jump_player()
	
	# Cek apakah sudah mencapai target 5x QTE
	if current_qte_success >= qte_target_count:
		await get_tree().create_timer(0.4).timeout
		finish_chase_sequence()
	else:
		await get_tree().create_timer(0.8).timeout
		spawn_next_qte()

func on_qte_missed() -> void:
	current_miss_count += 1
	play_hit_effect()
	
	if current_miss_count >= max_miss_allowed:
		await get_tree().create_timer(0.4).timeout
		trigger_game_over()
	else:
		await get_tree().create_timer(1.0).timeout
		spawn_next_qte()

func play_hit_effect() -> void:
	if not player:
		return
		
	var tween = create_tween()
	tween.tween_property(player, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(player, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(player, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(player, "modulate", Color(1, 1, 1, 1), 0.1)

	if camera_2d:
		var cam_tween = create_tween()
		cam_tween.tween_property(camera_2d, "global_position", Vector2(4, -81), 0.05)
		cam_tween.tween_property(camera_2d, "global_position", Vector2(-4, -89), 0.05)
		cam_tween.tween_property(camera_2d, "global_position", Vector2(0, -85), 0.05)

func trigger_game_over() -> void:
	is_chasing = false
	is_qte_active = false
	if qte_icon:
		qte_icon.visible = false
	
	if parallax_2d:
		parallax_2d.autoscroll.x = 0
	if player and player.has_method("stop_auto_walk"):
		player.stop_auto_walk()
		
	if game_over_panel:
		game_over_panel.visible = true

func _on_retry_button_pressed() -> void:
	var current_scene_path = "res://scene/World/world_hutanbakar.tscn"
	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(current_scene_path)
	else:
		get_tree().reload_current_scene()

# --- FUNGSI FINISH CHASE (DANUM MELUNCUR KELUAR LAYAR) ---

func finish_chase_sequence() -> void:
	# 1. Lepas kuncian posisi & matikan UI QTE
	is_chasing = false
	is_qte_active = false
	if qte_icon:
		qte_icon.visible = false
	
	# 2. Efek Danum meluncur kencang ke kanan keluar dari viewport
	if player:
		var dash_tween = create_tween()
		var target_escape_x: float = 500.0 # Titik koordinat jauh di luar layar kanan
		
		# Meluncur kencang ke kanan selama 0.7 detik dengan efek akselerasi (EASE_IN)
		dash_tween.tween_property(player, "global_position:x", target_escape_x, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		await dash_tween.finished

	# 3. Hentikan guliran latar belakang
	if parallax_2d:
		parallax_2d.autoscroll.x = 0
	
	# 4. Pindah ke scene berikutnya
	var target_scene_path = "res://scene/World/world_sembunyi.tscn"
	
	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(target_scene_path)
	elif SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		get_tree().change_scene_to_file(target_scene_path)
	else:
		get_tree().change_scene_to_file(target_scene_path)
