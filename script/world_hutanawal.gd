extends Node2D

@onready var player: Player = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var camera_point: Node2D = $CameraPoint

@onready var logo_texture: TextureRect = find_child("TextureRect", true, false) as TextureRect
@onready var center_trigger: Area2D = find_child("CenterTrigger", true, false) as Area2D

# --- PENGATURAN ZOOM & OFFSET KAMERA SINEMATIK ---
var intro_zoom: Vector2 = Vector2(1.5, 1.5)
var normal_zoom: Vector2 = Vector2(1.0, 1.0)

var intro_offset: Vector2 = Vector2(0, 40.0)
var normal_offset: Vector2 = Vector2.ZERO

var original_camera_offset: Vector2 = Vector2.ZERO
var has_switched_camera: bool = false
var is_camera_following: bool = false

func _ready() -> void:
	# 1. SEMBUNYIKAN LOGO STUDIO DI AWAL
	if logo_texture:
		logo_texture.visible = true
		logo_texture.modulate.a = 0.0

	# 2. SET KAMERA KE ZOOM IN & FOKUS AGAK BAWAH
	if camera_2d:
		camera_2d.zoom = intro_zoom
		camera_2d.offset = intro_offset
		# Aktifkan top_level agar posisi kamera bisa kita atur penuh lewat script
		camera_2d.top_level = true

	# 3. PINDAHKAN DANUM KE SPAWNPOINT
	var spawn_point = find_child("SpawnPoint", true, false)
	if spawn_point and player:
		player.global_position = spawn_point.global_position
	
	# 4. KUNCI POSISI KAMERA AWAL TEPAT DI CAMERAPOINT (STILL CAMERA)
	if camera_2d and camera_point:
		original_camera_offset = camera_2d.position
		camera_2d.global_position = Vector2(
			camera_point.global_position.x,
			player.global_position.y + original_camera_offset.y
		)

	# 5. HUBUNGKAN SINYAL BENTURAN
	if center_trigger and not center_trigger.body_entered.is_connected(_on_center_trigger_body_entered):
		center_trigger.body_entered.connect(_on_center_trigger_body_entered)

	# 6. LAYAR ME-FADE IN
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 7. MULAI JALAN OTOMATIS DARI LUAR LAYAR
	if player:
		player.start_auto_walk(1.0)

func _physics_process(_delta: float) -> void:
	if not camera_2d or not is_instance_valid(player):
		return
		
	# Awal masuk scene: Kamera diam di X CameraPoint, tapi ngikut Y player
	if camera_2d.top_level and not is_camera_following:
		if camera_point:
			camera_2d.global_position = Vector2(
				camera_point.global_position.x,
				player.global_position.y + original_camera_offset.y
			)
	# Setelah menabrak titik tengah: Kamera menguntit posisi player (X & Y) penuh
	elif camera_2d.top_level and is_camera_following:
		camera_2d.global_position = player.global_position + original_camera_offset

# FUNGSI DIPANGGIL TEPAT SAAT DANUM MENYENTUH TITIK TENGAH (CAMERAPOINT)
func _on_center_trigger_body_entered(body: Node2D) -> void:
	if body == player and not has_switched_camera:
		has_switched_camera = true
		is_camera_following = true # Mulai ikuti player saat bergerak
		run_logo_sequence()

func run_logo_sequence() -> void:
	# A. Fade In Logo Studio
	await fade_logo_image(true)
	
	# B. Tampil logo selama 2 detik
	await get_tree().create_timer(2.0).timeout
	
	# C. Fade Out Logo Studio
	await fade_logo_image(false)
	
	# D. Sisa jalan 0.5 detik
	await get_tree().create_timer(0.5).timeout
	
	# E. TRANSISI SMOOTH (ZOOM OUT + OFFSETS)
	await transition_camera_to_normal()
	
	# F. Serahkan kontrol penuh ke pemain
	if player:
		player.stop_auto_walk()

func fade_logo_image(appear: bool) -> void:
	if not logo_texture:
		return
		
	var tween = create_tween()
	if appear:
		logo_texture.visible = true
		tween.tween_property(logo_texture, "modulate:a", 1.0, 0.8)
		await tween.finished
	else:
		tween.tween_property(logo_texture, "modulate:a", 0.0, 0.8)
		await tween.finished
		logo_texture.visible = false

# TRANSISI SMOOTH KAMERA
func transition_camera_to_normal() -> void:
	if not camera_2d:
		return
		
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Animasi zoom dan offset mengendur kembali ke bentuk normal
	tween.tween_property(camera_2d, "zoom", normal_zoom, 1.2)
	tween.tween_property(camera_2d, "offset", normal_offset, 1.2)
	
	await tween.finished
	
	# Matikan top_level agar kamera kembali menempel normal sebagai child dari Player
	is_camera_following = false
	camera_2d.top_level = false
	camera_2d.position = original_camera_offset
