extends Node2D

@onready var player: CharacterBody2D = $Player

@export var cam_limit_left: int = -288
@export var cam_limit_right: int = 1104
@export var cam_limit_top: int = -290

func _ready() -> void:
	# Cek semua variabel global yang disimpan oleh area_exit.gd di GameState atau QuestManager
	var spawn_id: String = ""
	if "next_spawn_id" in GameState and str(GameState.next_spawn_id) != "":
		spawn_id = str(GameState.next_spawn_id)
		GameState.next_spawn_id = ""
	elif "target_spawn_id" in GameState and str(GameState.target_spawn_id) != "":
		spawn_id = str(GameState.target_spawn_id)
		GameState.target_spawn_id = ""
	elif "next_spawn_id" in QuestManager and str(QuestManager.next_spawn_id) != "":
		spawn_id = str(QuestManager.next_spawn_id)
		QuestManager.next_spawn_id = ""
	elif "target_spawn_id" in QuestManager and str(QuestManager.target_spawn_id) != "":
		spawn_id = str(QuestManager.target_spawn_id)
		QuestManager.target_spawn_id = ""

	if spawn_id != "":
		var spawn_node := get_node_or_null(spawn_id) as Node2D
		if spawn_node and player:
			player.global_position = spawn_node.global_position

	# Terapkan batas kamera setelah posisi player ditetapkan
	if player:
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left = cam_limit_left
			cam.limit_right = cam_limit_right
			cam.limit_top = cam_limit_top
			cam.reset_smoothing()
