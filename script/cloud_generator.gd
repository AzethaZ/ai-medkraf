extends Node2D

# Masukkan 3 gambar awan di Inspector (awan1.png, awan2.png, awan3.png)
@export var cloud_textures: Array[Texture2D] = []

# Ketinggian Y awan (angka lebih minus = lebih ke atas langit)
@export var min_y: float = -175.0
@export var max_y: float = -115.0

# Kecepatan gerak awan dari kanan ke kiri (pixel per detik)
@export var min_speed: float = 16.0
@export var max_speed: float = 30.0
@export var spawn_interval: float = 6.5
@export var max_clouds: int = 3

@onready var spawn_timer: Timer = $Timer

var active_clouds: Array[Dictionary] = []

func _ready() -> void:
	position = Vector2.ZERO
	await get_tree().process_frame
	
	var half_width := _get_screen_half_width()
	# Hanya munculkan 2 awan di awal agar langit tidak penuh
	for i in range(2):
		var start_offset = randf_range(-half_width * 0.6, half_width * 0.8)
		_spawn_cloud(start_offset)
		
	if spawn_timer:
		spawn_timer.wait_time = spawn_interval
		spawn_timer.one_shot = false
		if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
			spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.start()

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	var cam_center_x: float = cam.get_screen_center_position().x if cam else 0.0
	var half_width := _get_screen_half_width()
	var margin := 120.0
	
	for i in range(active_clouds.size() - 1, -1, -1):
		var data = active_clouds[i]
		var sprite: Sprite2D = data["node"]
		
		if is_instance_valid(sprite):
			data["offset_x"] -= data["speed"] * delta
			sprite.global_position = Vector2(cam_center_x + data["offset_x"], data["y"])
			
			# Hapus awan jika sudah lewat tepi kiri layar (biarkan Timer yang mengatur spawn berikutnya)
			if data["offset_x"] < -(half_width + margin):
				sprite.queue_free()
				active_clouds.remove_at(i)
		else:
			active_clouds.remove_at(i)

func _on_spawn_timer_timeout() -> void:
	if active_clouds.size() < max_clouds:
		var half_width := _get_screen_half_width()
		_spawn_cloud(half_width + 120.0)

func _spawn_cloud(initial_offset_x: float) -> void:
	if cloud_textures.is_empty():
		return
		
	var cloud := Sprite2D.new()
	cloud.texture = cloud_textures.pick_random()
	
	var pos_y := randf_range(min_y, max_y)
	var random_scale := randf_range(0.85, 1.1)
	cloud.scale = Vector2(random_scale, random_scale)
	cloud.modulate.a = randf_range(0.8, 0.95)
	
	var cam := get_viewport().get_camera_2d()
	var cam_center_x: float = cam.get_screen_center_position().x if cam else 0.0
	cloud.global_position = Vector2(cam_center_x + initial_offset_x, pos_y)
	
	add_child(cloud)
	
	active_clouds.append({
		"node": cloud,
		"offset_x": initial_offset_x,
		"y": pos_y,
		"speed": randf_range(min_speed, max_speed)
	})

func _get_screen_half_width() -> float:
	var cam := get_viewport().get_camera_2d()
	var zoom_x: float = cam.zoom.x if cam else 1.0
	return (get_viewport_rect().size.x / zoom_x) * 0.5
