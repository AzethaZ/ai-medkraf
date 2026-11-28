extends Node2D

@export var spawn_x_right: float = 200.0 # Titik X muncul di kanan map world_4
@export var despawn_x_left: float = -1800.0 # Titik X hapus di kiri map world_4
@export var y_jitter: float = 0.0 # Variasi naik-turun tipis dari posisi Y sprite di Editor (0 = persis seperti di Editor)

@export var speed_min: float = 18.0 # Kecepatan gerak paling pelan (kanan ke kiri)
@export var speed_max: float = 42.0 # Kecepatan gerak paling cepat

@export var scale_multiplier_min: float = 0.85
@export var scale_multiplier_max: float = 1.2

@export var spawn_interval_min: float = 3.5 # Jeda antar awan muncul (detik)
@export var spawn_interval_max: float = 7.0
@export var max_active_clouds: int = 8
@export var prewarm_count: int = 4 # Jumlah awan yang langsung ada saat scene dibuka

@export var pause_when_player_moves: bool = true # Awan diam saat Danum bergerak, mengalir lagi saat Danum diam

var _cloud_templates: Array[Sprite2D] = []
var _active_clouds: Array[Dictionary] = []
var _player: Node2D = null

func _ready() -> void:
	_player = _find_player()

	# Ambil semua child Sprite2D (awan_1, awan_2, awan_3) sebagai template
	for child in get_children():
		if child is Sprite2D:
			child.visible = false
			_cloud_templates.append(child)

	if _cloud_templates.is_empty():
		return

	# Langsung isi langit dengan beberapa awan saat scene baru dibuka
	for i in range(prewarm_count):
		var random_start_x := randf_range(despawn_x_left + 300.0, spawn_x_right)
		_spawn_cloud(random_start_x)

	_schedule_next_spawn()

func _find_player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(p):
		return p
	if get_tree().current_scene:
		p = get_tree().current_scene.find_child("Player", true, false) as Node2D
	return p

func _is_player_moving() -> bool:
	if not is_instance_valid(_player):
		_player = _find_player()
	if is_instance_valid(_player) and _player is CharacterBody2D:
		return abs(_player.velocity.x) > 5.0
	return false

func _process(delta: float) -> void:
	if pause_when_player_moves and _is_player_moving():
		return

	for i in range(_active_clouds.size() - 1, -1, -1):
		var data: Dictionary = _active_clouds[i]
		var sprite: Sprite2D = data["node"]
		var spd: float = data["speed"]

		if not is_instance_valid(sprite):
			_active_clouds.remove_at(i)
			continue

		# Gerakkan awan dari kanan ke kiri
		sprite.position.x -= spd * delta

		# Hapus setelah melewati batas kiri layar
		if sprite.position.x < despawn_x_left:
			sprite.queue_free()
			_active_clouds.remove_at(i)

func _schedule_next_spawn() -> void:
	if not is_inside_tree():
		return
	var wait_time := randf_range(spawn_interval_min, spawn_interval_max)
	await get_tree().create_timer(wait_time).timeout
	if not is_inside_tree():
		return

	# Jangan spawn awan baru jika Danum sedang bergerak
	if not (pause_when_player_moves and _is_player_moving()):
		if _active_clouds.size() < max_active_clouds:
			_spawn_cloud(spawn_x_right)

	_schedule_next_spawn()

func _spawn_cloud(start_x: float) -> void:
	if _cloud_templates.is_empty():
		return

	var template: Sprite2D = _cloud_templates.pick_random()
	var cloud := template.duplicate() as Sprite2D
	cloud.visible = true

	# Gunakan posisi Y sesuai yang diatur pada masing-masing sprite di Editor
	var spawn_y: float = template.position.y + randf_range(-y_jitter, y_jitter)
	cloud.position = Vector2(start_x, spawn_y)

	var mult := randf_range(scale_multiplier_min, scale_multiplier_max)
	cloud.scale = template.scale * mult

	add_child(cloud)
	_active_clouds.append({
		"node": cloud,
		"speed": randf_range(speed_min, speed_max)
	})
