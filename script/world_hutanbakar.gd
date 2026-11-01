extends Node2D

@export var qte_target_count: int = 5       # Target sukses 5x QTE
@export var max_miss_allowed: int = 2        # Maksimal 2x gagal -> Game Over
@export var scroll_speed: float = 200.0       # Kecepatan lari background (Parallax)

@onready var parallax_2d: Parallax2D = $Parallax2D
@onready var player: Player = $Player
@onready var npc_chaser: Node2D = find_child("NPC_Chaser", true, false)
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)
@onready var interact_icon: Sprite2D = npc_chaser.find_child("InteractIcon", true, false) if npc_chaser else null

# UI Node
@onready var qte_icon: Control = $ChaseUI/QTECircle
@onready var game_over_panel: Control = $ChaseUI/GameOverPanel
@onready var retry_button: Button = find_child("RetryButton", true, false) as Button

var current_qte_success: int = 0
var current_miss_count: int = 0
var is_chasing: bool = false
var is_qte_active: bool = false
var qte_pressed_in_time: bool = false

# ID unik untuk mencegah bentrokan timer QTE lama
var current_qte_id: int = 0

# Variabel posisi X asli dari Editor
var player_start_x: float = 0.0
var npc_start_x: float = 0.0
var is_scene_initialized: bool = false

func _ready() -> void:
	# 1. SEMBUNYIKAN UI & IKON DI AWAL
	if game_over_panel:
		game_over_panel.visible = false
	if qte_icon:
		qte_icon.visible = false
	if interact_icon:
		interact_icon.visible = false
		
	if retry_button and not retry_button.pressed.is_connected(_on_retry_button_pressed):
		retry_button.pressed.connect(_on_retry_button_pressed)

	# 2. SET KONTROL KAMERA DI TENGAH ARENA
	if camera_2d:
		camera_2d.top_level = true
		camera_2d.global_position = Vector2(0, -85)

	# 3. AMBIL POSISI DARI EDITOR & KUNCI KOORDINATNYA
	if player:
		player_start_x = player.global_position.x
		player.global_position.x = player_start_x
	if npc_chaser:
		npc_start_x = npc_chaser.global_position.x
		npc_chaser.global_position.x = npc_start_x

	is_scene_initialized = true

	if parallax_2d:
		parallax_2d.autoscroll.x = 0 # Background belum jalan

	# 4. FADE IN TRANSISI MASUK SCENE
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 5. MUNCULKAN INTERACT ICON (!) SEBENTAR DI ATAS NPC
	if interact_icon:
		interact_icon.visible = true
		await get_tree().create_timer(0.6).timeout
		interact_icon.visible = false

	# 6. PANGGIL DIALOG PRA-KEJAR
	await start_pre_chase_dialogue()

	# 7. MULAI KEJAR-KEJARAN
	start_chase_sequence()

func _process(_delta: float) -> void:
	# Menjaga posisi X karakter tetap konsisten sesuai Editor
	if is_scene_initialized:
		if player:
			player.global_position.x = player_start_x
		if npc_chaser:
			npc_chaser.global_position.x = npc_start_x

# --- ALUR DIALOG PRE-CHASE ---

func start_pre_chase_dialogue() -> void:
	if npc_chaser and npc_chaser.has_method("show_chase_dialogue"):
		await npc_chaser.show_chase_dialogue("Kau tidak akan bisa lari, Danum!")
	else:
		await get_tree().create_timer(1.0).timeout

# --- MEKANIK KEJAR-KEJARAN & QTE ---

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
		qte_pressed_in_time = true
		is_qte_active = false
		if qte_icon:
			qte_icon.visible = false
		
		get_viewport().set_input_as_handled() # Mencegah input ganda
		on_qte_success()

func spawn_next_qte() -> void:
	if not is_chasing or not qte_icon:
		return
		
	if current_qte_success >= qte_target_count:
		finish_chase_sequence()
		return

	# Buat ID unik untuk QTE saat ini
	current_qte_id += 1
	var this_qte_id = current_qte_id
		
	var viewport_size = get_viewport_rect().size
	var random_x = randf_range(150, viewport_size.x - 150)
	var random_y = randf_range(150, viewport_size.y - 150)
	
	qte_icon.position = Vector2(random_x, random_y)
	qte_icon.visible = true
	
	is_qte_active = true
	qte_pressed_in_time = false
	
	# Batas waktu 2.0 detik
	await get_tree().create_timer(2.0).timeout
	
	# Pastikan ini masih QTE yang sama dan belum ditekan
	if is_qte_active and not qte_pressed_in_time and current_qte_id == this_qte_id:
		is_qte_active = false
		qte_icon.visible = false
		on_qte_missed()

func on_qte_success() -> void:
	current_qte_success += 1
	await get_tree().create_timer(0.8).timeout
	spawn_next_qte()

func on_qte_missed() -> void:
	current_miss_count += 1
	if current_miss_count >= max_miss_allowed:
		trigger_game_over()
	else:
		await get_tree().create_timer(0.8).timeout
		spawn_next_qte()

# --- GAME OVER, RETRY & TRANSISI SCENE ---

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

func finish_chase_sequence() -> void:
	is_chasing = false
	is_qte_active = false
	if qte_icon:
		qte_icon.visible = false
	
	if parallax_2d:
		parallax_2d.autoscroll.x = 0
	
	var target_scene_path = "res://scene/World/world_sembunyi.tscn"
	
	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(target_scene_path)
	elif SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		get_tree().change_scene_to_file(target_scene_path)
	else:
		get_tree().change_scene_to_file(target_scene_path)
