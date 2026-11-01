extends Node2D

@onready var player: Player = $Player
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var camera_point: Node2D = $CameraPoint

@onready var logo_texture: TextureRect = find_child("TextureRect", true, false) as TextureRect
@onready var center_trigger: Area2D = find_child("CenterTrigger", true, false) as Area2D

var has_switched_camera: bool = false
var original_camera_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 1. SEMBUNYIKAN LOGO STUDIO DI AWAL
	if logo_texture:
		logo_texture.visible = true
		logo_texture.modulate.a = 0.0

	# 2. PINDAHKAN DANUM KE SPAWNPOINT TERLEBIH DAHULU (Sebelum mengunci kamera)
	var spawn_point = find_child("SpawnPoint", true, false)
	if spawn_point and player:
		player.global_position = spawn_point.global_position
	
	# 3. KUNCI POSISI KAMERA EKSPLISIT DI CAMERAPOINT (STILL CAMERA)
	if camera_2d and camera_point:
		original_camera_offset = camera_2d.position
		
		# Aktifkan top_level
		camera_2d.top_level = true
		
		# Kunci posisi global kamera tepat di koordinat CameraPoint
		camera_2d.global_position = Vector2(
			camera_point.global_position.x,
			player.global_position.y + original_camera_offset.y
		)

	# 4. HUBUNGKAN SINYAL AREA2D BENTURAN
	if center_trigger and not center_trigger.body_entered.is_connected(_on_center_trigger_body_entered):
		center_trigger.body_entered.connect(_on_center_trigger_body_entered)

	# 5. LAYAR ME-FADE IN (Kamera diam di CameraPoint, layar mulai terang)
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 6. MULAI JALAN OTOMATIS DARI LUAR LAYAR
	if player:
		player.start_auto_walk(1.0)

# FUNGSI DIPANGGIL TEPAT SAAT DANUM MENYENTUH TITIK TENGAH (CAMERAPOINT)
func _on_center_trigger_body_entered(body: Node2D) -> void:
	if body == player and not has_switched_camera:
		has_switched_camera = true
		
		# Kembalikan kamera ke Player tepat di tengah layar
		if camera_2d:
			camera_2d.top_level = false
			camera_2d.position = original_camera_offset
		
		# Jalankan urutan animasi logo studio
		run_logo_sequence()

func run_logo_sequence() -> void:
	# A. Fade In Logo Studio
	await fade_logo_image(true)
	
	# B. Tampil logo selama 2 detik
	await get_tree().create_timer(2.0).timeout
	
	# C. Fade Out Logo Studio
	await fade_logo_image(false)
	
	# D. Sisa jalan 0.5 detik lalu serahkan kontrol ke pemain
	await get_tree().create_timer(0.5).timeout
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
