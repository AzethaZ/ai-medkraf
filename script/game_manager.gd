extends Node

enum StoryStep {
	CUTSCENE_AWAL,
	GAMEPLAY_1_HUTAN,
	CUTSCENE_HUTAN_1,
	GAMEPLAY_2_DIKEJAR,
	CUTSCENE_HUTAN_2
}

var current_step: StoryStep = StoryStep.CUTSCENE_AWAL

func advance_story(next_step: StoryStep) -> void:
	current_step = next_step
	print("Progres cerita diperbarui ke: ", current_step)

# -----------------------------------
# SISTEM INVENTORY UMUM
# -----------------------------------
var inventory: Array = []

func add_item(item_data: Dictionary) -> void:
	inventory.append(item_data)
	print("Inventaris saat ini: ", inventory)

var current_area = 1
var area_path = "res://scene/World/"

# -----------------------------------
# PERPINDAHAN WORLD / SCENE
# -----------------------------------
func next_level(target_scene_path: String = "res://scene/World/world_2.tscn") -> void:
	call_deferred("_change_world", target_scene_path)

func previous_level(target_scene_path: String = "res://scene/World/world_1.tscn") -> void:
	call_deferred("_change_world", target_scene_path)

func _change_world(target_scene_path: String) -> void:
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()

	get_tree().change_scene_to_file(target_scene_path)

	if has_method("_teleport_player_to_spawn"):
		await _teleport_player_to_spawn()

	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

func _teleport_player_to_spawn():
	await get_tree().tree_changed
	await get_tree().process_frame

	var current_scene = get_tree().current_scene
	if current_scene:
		var player = current_scene.get_node_or_null("Player")
		var spawn_point = current_scene.get_node_or_null("SpawnPoint")

		if player and spawn_point:
			player.global_position = spawn_point.global_position

# -----------------------------------
# HELPER INVENTORY DETAIL
# -----------------------------------
func get_item_count(item_name: String) -> int:
	var count = 0
	for item in inventory:
		if item.has("name") and item["name"] == item_name:
			count += 1
	return count

func remove_item(item_name: String, amount: int) -> void:
	var removed_count = 0
	for i in range(inventory.size() - 1, -1, -1):
		if inventory[i].has("name") and item_name == inventory[i]["name"]:
			inventory.remove_at(i)
			removed_count += 1
			if removed_count >= amount:
				break

# -----------------------------------
# PENCATATAN OBJEK DI DUNIA (SPAWN TRACKER)
# -----------------------------------
var collected_items: Array[String] = []

func mark_item_collected(item_id: String) -> void:
	if item_id != "" and not collected_items.has(item_id):
		collected_items.append(item_id)

func collect_item(item_id: String) -> void:
	mark_item_collected(item_id)

func is_item_collected(item_id: String) -> bool:
	if item_id == "": return false
	return collected_items.has(item_id)

# Variabel global untuk menyimpan jumlah/tipe follower yang aktif
var follower_count: int = 0
@export var chick_follower_scene: PackedScene = preload("res://scene/chick.tscn")

func add_follower_data() -> void:
	follower_count += 1

func clear_followers_data() -> void:
	follower_count = 0
