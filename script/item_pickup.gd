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
var current_player_node: Node2D = null
var tween: Tween
var initial_icon_y: float


func _ready() -> void:
	# Cek apakah item ini sudah pernah diambil sebelumnya
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


func _is_quest_active() -> bool:
	if QuestManager and QuestManager.has_method("get_quest_status"):
		return QuestManager.get_quest_status(target_quest_id) == "ACTIVE"
	return true # Fallback jika QuestManager tidak membatasi status


func _unhandled_input(event: InputEvent) -> void:
	# HANYA BISA INTERAKSI JIKA QUEST SUDAH ACTIVE
	if is_player_inside and not is_minigame_active and _is_quest_active():
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.is_pressed() and not event.is_echo()):
			get_viewport().set_input_as_handled()
			start_chick_minigame()


func start_chick_minigame() -> void:
	var minigame_ui: Node = null
	
	if current_player_node and current_player_node.has_node("RhythmMinigame"):
		minigame_ui = current_player_node.get_node("RhythmMinigame")
	if not minigame_ui:
		minigame_ui = get_tree().current_scene.find_child("RhythmMinigame", true, false)

	if minigame_ui:
		is_minigame_active = true
		stop_hover_animation()
		
		if minigame_ui.has_signal("minigame_completed"):
			if minigame_ui.minigame_completed.is_connected(_on_minigame_completed):
				minigame_ui.minigame_completed.disconnect(_on_minigame_completed)
			minigame_ui.minigame_completed.connect(_on_minigame_completed)
			
		if minigame_ui.has_method("start_minigame"):
			# Tentukan pola berdasarkan item_id anak ayam
			var pattern_id: int = 1
			if item_id == "ayam_2":
				pattern_id = 2  # Pola Segitiga (3 ketukan, lambat)
			elif item_id == "ayam_3":
				pattern_id = 3  # Pola Pentagon (5 ketukan)
			else:
				pattern_id = 1  # Pola Kotak (4 ketukan)
				
			minigame_ui.start_minigame(pattern_id)


func _on_minigame_completed(success: bool) -> void:
	is_minigame_active = false
	
	if success:
		spawn_and_add_chick_follower()
	else:
		if is_player_inside and _is_quest_active():
			start_hover_animation()


func spawn_and_add_chick_follower() -> void:
	var player = current_player_node
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)

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

	if QuestManager:
		if QuestManager.has_method("collect_chick"):
			QuestManager.collect_chick(item_id)
		elif QuestManager.has_method("add_quest_progress"):
			QuestManager.add_quest_progress(target_quest_id, 1)

	queue_free()


# --- DETEKSI AREA PLAYER ---
func _on_body_entered(body: Node2D) -> void:
	if _is_player_node(body):
		is_player_inside = true
		current_player_node = body
		# HANYA TAMPILKAN IKON INTERAKSI JIKA QUEST SUDAH ACTIVE
		if _is_quest_active():
			start_hover_animation()


func _on_body_exited(body: Node2D) -> void:
	if _is_player_node(body):
		is_player_inside = false
		current_player_node = null
		stop_hover_animation()


func _is_player_node(body: Node2D) -> bool:
	if not body:
		return false
	return body.is_in_group("player") or body.name == "Player" or body.name.begins_with("Player") or body is CharacterBody2D


func start_hover_animation() -> void:
	if not interact_icon:
		return
	interact_icon.visible = true

	if tween and tween.is_running():
		tween.kill()

	tween = create_tween().set_loops()
	tween.tween_property(interact_icon, "position:y", initial_icon_y - 5.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(interact_icon, "position:y", initial_icon_y, 0.4).set_trans(Tween.TRANS_SINE)


func stop_hover_animation() -> void:
	if not interact_icon:
		return
	interact_icon.visible = false
	if tween and tween.is_running():
		tween.kill()
	interact_icon.position.y = initial_icon_y
