extends Area2D

@export var chick_scene: PackedScene
@export var item_id: String = ""
@export var item_name: String = "Anak Ayam"
@export var item_icon: Texture2D
@export var target_quest_id: String = "quest_ayam_1"

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var interact_icon: Sprite2D = $InteractIcon

var is_player_inside: bool = false
var is_minigame_active: bool = false
var tween: Tween
var initial_icon_y: float


func _ready() -> void:
	# 1. Cek apakah item ini sudah pernah diambil sebelumnya
	var is_collected: bool = false
	if item_id != "":
		if GameManager and GameManager.has_method("is_item_collected") and GameManager.is_item_collected(item_id):
			is_collected = true
		elif QuestManager and QuestManager.has_method("is_chick_collected") and QuestManager.is_chick_collected(item_id):
			is_collected = true

	if is_collected:
		queue_free()
		return

	if interact_icon:
		interact_icon.visible = false
		initial_icon_y = interact_icon.position.y

	if item_icon and sprite_2d:
		sprite_2d.texture = item_icon

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and not is_minigame_active:
		# KETAT: Cek apakah quest sudah diawali/diaktifkan dari world_3
		if QuestManager and QuestManager.has_method("get_quest_status"):
			var quest_status = QuestManager.get_quest_status(target_quest_id)
			if quest_status != "ACTIVE":
				# Jika status quest bukan ACTIVE (masih NOT_STARTED), tolak interaksi!
				return

		# Pemicu tombol interact (E / Enter / Space)
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.is_pressed() and event.keycode == KEY_E):
			get_viewport().set_input_as_handled()
			start_chick_minigame()


func start_chick_minigame() -> void:
	var minigame_ui = get_tree().current_scene.find_child("RhythmMinigame", true, false)
	
	if minigame_ui:
		is_minigame_active = true

		if minigame_ui.has_signal("minigame_completed"):
			if minigame_ui.minigame_completed.is_connected(_on_minigame_completed):
				minigame_ui.minigame_completed.disconnect(_on_minigame_completed)
			minigame_ui.minigame_completed.connect(_on_minigame_completed)

		if minigame_ui.has_method("start_minigame"):
			minigame_ui.start_minigame()
	else:
		print("PERINGATAN: Node RhythmMinigame belum dimasukkan ke scene ", get_tree().current_scene.name)


func _on_minigame_completed(success: bool) -> void:
	is_minigame_active = false

	if success:
		spawn_and_add_chick_follower()
	else:
		is_player_inside = true


func spawn_and_add_chick_follower() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not player:
		for child in get_tree().current_scene.get_children():
			if child.is_in_group("player") or child is CharacterBody2D:
				player = child
				break

	if chick_scene and player:
		var new_chick = chick_scene.instantiate() as Node2D
		get_tree().current_scene.add_child(new_chick)
		new_chick.global_position = global_position

		if player.has_method("add_follower"):
			player.add_follower(new_chick)

	if GameManager and GameManager.has_method("add_follower_data"):
		GameManager.add_follower_data()

	if GameManager and GameManager.has_method("collect_item"):
		GameManager.collect_item(item_id)

	# Update progres quest persisten (3/3)
	if QuestManager:
		if QuestManager.has_method("collect_chick"):
			QuestManager.collect_chick(item_id)
		elif QuestManager.has_method("add_quest_progress"):
			QuestManager.add_quest_progress(target_quest_id, 1)

	queue_free()


# --- PEMERIKSAAN BODY ENTERED & EXITED ---
func _on_body_entered(body: Node2D) -> void:
	if _is_player_node(body):
		is_player_inside = true
		
		# HANYA TAMPILKAN IKON INTERAKSI JIKA QUEST SUDAH ACTIVE
		if QuestManager and QuestManager.has_method("get_quest_status"):
			if QuestManager.get_quest_status(target_quest_id) == "ACTIVE":
				start_hover_animation()
		else:
			start_hover_animation()


func _on_body_exited(body: Node2D) -> void:
	if _is_player_node(body):
		is_player_inside = false
		stop_hover_animation()


func _is_player_node(body: Node2D) -> bool:
	if not body: return false
	return body.is_in_group("player") or body.name == "Player" or body.name.begins_with("Player") or body is CharacterBody2D


func start_hover_animation() -> void:
	if not interact_icon: return
	interact_icon.visible = true

	if tween and tween.is_running(): tween.kill()

	tween = create_tween().set_loops()
	tween.tween_property(interact_icon, "position:y", initial_icon_y - 5.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(interact_icon, "position:y", initial_icon_y, 0.4).set_trans(Tween.TRANS_SINE)


func stop_hover_animation() -> void:
	if not interact_icon: return
	interact_icon.visible = false

	if tween and tween.is_running(): tween.kill()
	interact_icon.position.y = initial_icon_y
