extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

func _ready() -> void:
	# 1. Matikan kontrol pergerakan pemain sejenak saat layar masih hitam
	if player and player.has_method("disable_movement"):
		player.disable_movement()

	# 2. Tentukan spawn point target (jika kosong, gunakan default "SpawnPoint")
	var spawn_name: String = "SpawnPoint"
	if SceneTransition and "target_spawn_id" in SceneTransition and SceneTransition.target_spawn_id != "":
		spawn_name = SceneTransition.target_spawn_id
		SceneTransition.target_spawn_id = "" # Reset setelah diambil

	# Pindahkan posisi player secara deferred agar posisinya pas
	call_deferred("_move_player_to_spawn", spawn_name)

	# 3. Setup Kamera Ruangan
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()

	# 4. Transisi Fade In
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 5. Kembalikan kontrol pergerakan ke pemain
	if player and player.has_method("enable_movement"):
		player.enable_movement()

# --- FUNGSI HELPER PEMINDAHAN POSISI SPAWN ---
func _move_player_to_spawn(spawn_name: String) -> void:
	var spawn_node = find_child(spawn_name, true, false)
	if spawn_node and player:
		player.global_position = spawn_node.global_position
