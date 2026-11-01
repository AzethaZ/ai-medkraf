extends Node2D

@export var qte_target_count: int = 5       # Target sukses 5x QTE
@export var max_miss_allowed: int = 2        # Maksimal 2x gagal -> Game Over
@export var scroll_speed: float = 260.0       # Kecepatan lari background (Parallax)

@onready var parallax_2d: Parallax2D = $Parallax2D
@onready var player: Player = $Player
@onready var npc_chaser: Node2D = find_child("NPC_Chaser", true, false)
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

# UI Node
@onready var qte_icon: Control = $ChaseUI/QTECircle  # TextureRect/Control penanda visual QTE
@onready var game_over_panel: Control = $ChaseUI/GameOverPanel
@onready var retry_button: Button = find_child("RetryButton", true, false) as Button

var current_qte_success: int = 0
var current_miss_count: int = 0
var is_chasing: bool = true

# State melacak status QTE aktif
var is_qte_active: bool = false
var qte_pressed_in_time: bool = false

# Mengambil reference InteractIcon di dalam NPC_Chaser
@onready var interact_icon: Sprite2D = npc_chaser.find_child("InteractIcon", true, false) if npc_chaser else null

func _ready() -> void:
	# 1. SEMBUNYIKAN UI & ICON DI AWAL
	if game_over_panel:
		game_over_panel.visible = false
	if qte_icon:
		qte_icon.visible = false
	if interact_icon:
		interact_icon.visible = false  # Sembunyikan ikon tanda seru bawaan NPC
		
	if retry_button and not retry_button.pressed.is_connected(_on_retry_button_pressed):
		retry_button.pressed.connect(_on_retry_button_pressed)

	# 2. SETUP KAMERA STILL & POSISI AWAL (BACKGROUND MASIH DIAM)
	if camera_2d:
		camera_2d.top_level = true
		camera_2d.global_position = Vector2(0, -85)

	if player:
		player.global_position.x = 130.0

	if npc_chaser:
		npc_chaser.global_position.x = -130.0

	if parallax_2d:
		parallax_2d.autoscroll.x = 0  # Background belum jalan

	# 3. FADE IN TRANSISI MASUK SCENE
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 4. MUNCULKAN INTERACT ICON (!) SELAMA 0.8 DETIK
	if interact_icon:
		interact_icon.visible = true
		await get_tree().create_timer(0.8).timeout
		interact_icon.visible = false

	# 5. MULAI KEJAR-KEJARAN (BACKGROUND JALAN & ANIMASI LARI)
	if parallax_2d:
		parallax_2d.autoscroll.x = -scroll_speed

	if player and player.has_method("start_auto_walk"):
		player.start_auto_walk(1.5)

	if npc_chaser and npc_chaser.has_method("start_chase"):
		npc_chaser.start_chase()

	# 6. JEDA 0.5 DETIK LALU SPAWN QTE PERTAMA
	await get_tree().create_timer(0.5).timeout
	spawn_next_qte()

func _process(_delta: float) -> void:
	# Menjaga posisi X karakter tetap konsisten di posisinya masing-masing saat animasi lari
	if is_chasing:
		if player:
			player.global_position.x = 130.0
		if npc_chaser:
			npc_chaser.global_position.x = -130.0

# --- INPUT LISTENER UNTUK TOMBOL INTERAKSI (E) ---

func _unhandled_input(event: InputEvent) -> void:
	# Cek apakah pemain menekan tombol "interact" (tombol E) saat QTE aktif
	if is_chasing and is_qte_active and event.is_action_pressed("interact"):
		qte_pressed_in_time = true
		is_qte_active = false
		if qte_icon:
			qte_icon.visible = false
		
		on_qte_success()

# --- MEKANIK SPANNER QTE LINGKARAN ---

func spawn_next_qte() -> void:
	if not is_chasing or not qte_icon:
		return
		
	# Cek apakah target 5x sukses sudah tercapai
	if current_qte_success >= qte_target_count:
		finish_chase_sequence()
		return
		
	# Acak posisi visual ikon QTE di area layar UI
	var viewport_size = get_viewport_rect().size
	var random_x = randf_range(150, viewport_size.x - 150)
	var random_y = randf_range(150, viewport_size.y - 150)
	
	qte_icon.position = Vector2(random_x, random_y)
	qte_icon.visible = true
	
	# Reset state QTE
	is_qte_active = true
	qte_pressed_in_time = false
	
	# Waktu toleransi 2.0 detik bagi pemain untuk menekan tombol 'E'
	var qte_timer = get_tree().create_timer(2.0)
	await qte_timer.timeout
	
	# Jika timer habis dan pemain BELUM menekan 'E'
	if is_qte_active and not qte_pressed_in_time:
		is_qte_active = false
		qte_icon.visible = false
		on_qte_missed()

func on_qte_success() -> void:
	current_qte_success += 1
	print("QTE Berhasil! Progres: ", current_qte_success, "/", qte_target_count)
	
	# Jeda santai 0.8 detik sebelum lingkaran berikutnya muncul
	await get_tree().create_timer(0.8).timeout
	spawn_next_qte()

func on_qte_missed() -> void:
	current_miss_count += 1
	print("QTE Miss! Total Miss: ", current_miss_count)
	
	# Jika sudah 2x miss -> GAME OVER
	if current_miss_count >= max_miss_allowed:
		trigger_game_over()
	else:
		# Jeda sebelum QTE berikutnya muncul
		await get_tree().create_timer(0.8).timeout
		spawn_next_qte()

# --- HANDLER GAME OVER, RETRY & FINISH SCENE ---

func trigger_game_over() -> void:
	is_chasing = false
	is_qte_active = false
	if qte_icon:
		qte_icon.visible = false
	
	# Hentikan autoscroll background & lari player
	if parallax_2d:
		parallax_2d.autoscroll.x = 0
	if player and player.has_method("stop_auto_walk"):
		player.stop_auto_walk()
		
	# Tampilkan UI Game Over
	if game_over_panel:
		game_over_panel.visible = true

func _on_retry_button_pressed() -> void:
	# Mengulang scene kejar-kejaran dari awal
	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene("res://scene/World/world_hutanbakar.tscn")
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
	
	# Transisi me-fade out layar lalu berpindah ke world_sembunyi.tscn
	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(target_scene_path)
	elif SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		get_tree().change_scene_to_file(target_scene_path)
	else:
		get_tree().change_scene_to_file(target_scene_path)
