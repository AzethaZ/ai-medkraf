extends Node

var current_area = 1
var area_path = "res://scene/World/"

func next_level():
	current_area += 1
	# Gunakan call_deferred agar scene berganti setelah proses fisika selesai
	call_deferred("_change_world")

func previous_level():
	if current_area > 1:
		current_area -= 1
		call_deferred("_change_world")

func _change_world():
	var full_path = area_path + "world_" + str(current_area) + ".tscn"
	get_tree().change_scene_to_file(full_path)
	_teleport_player_to_spawn()

func _teleport_player_to_spawn():
	# Tunggu sampai scene baru benar-benar selesai dimuat ke tree
	await get_tree().tree_changed
	await get_tree().process_frame
	
	var current_scene = get_tree().current_scene
	if current_scene:
		var player = current_scene.get_node_or_null("Player")
		var spawn_point = current_scene.get_node_or_null("SpawnPoint")
		
		if player and spawn_point:
			player.global_position = spawn_point.global_position
