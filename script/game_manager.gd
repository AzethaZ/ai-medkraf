extends Node

var inventory: Array = []

func add_item(item_data: Dictionary) -> void:
	inventory.append(item_data)
	print("Inventaris saat ini: ", inventory)

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
	# 1. Layar perlahan menjadi hitam
	await SceneTransition.fade_out()
	
	# 2. Ganti scene di belakang layar hitam
	var full_path = area_path + "world_" + str(current_area) + ".tscn"
	get_tree().change_scene_to_file(full_path)
	
	# 3. Teleport player ke spawn point
	await _teleport_player_to_spawn()
	
	# 4. Layar perlahan kembali terang
	await SceneTransition.fade_in()

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
			
# --- FUNGSI MANAJEMEN INVENTORY ---

# 1. Menghitung jumlah item berdasarkan nama
func get_item_count(item_name: String) -> int:
	var count = 0
	for item in inventory:
		# Sesuaikan key "name" dengan struktur data item di GameManager-mu
		if item.has("name") and item["name"] == item_name:
			count += 1
	return count

# 2. Menghapus item sejumlah 'amount' dari inventory
func remove_item(item_name: String, amount: int) -> void:
	var removed_count = 0
	# Looping dari belakang ke depan agar aman saat menghapus element Array
	for i in range(inventory.size() - 1, -1, -1):
		if inventory[i].has("name") and inventory[i]["name"] == item_name:
			inventory.remove_at(i)
			removed_count += 1
			if removed_count >= amount:
				break
