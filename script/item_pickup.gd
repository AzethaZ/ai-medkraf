extends Area2D

@export var chick_scene: PackedScene
@export var item_id: String = ""
@export var item_name: String = "Anak Ayam"
@export var item_icon: Texture2D
@export var target_quest_id: String = "quest_kandang_ayam"

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var interact_icon: Sprite2D = $InteractIcon

var is_player_inside: bool = false
var is_minigame_active: bool = false
var tween: Tween
var initial_icon_y: float

func _ready() -> void:
	if item_id != "" and GameManager.has_method("is_item_collected") and GameManager.is_item_collected(item_id):
		queue_free()
		return

	if interact_icon:
		interact_icon.visible = false
		initial_icon_y = interact_icon.position.y

	if item_icon and sprite_2d:
		sprite_2d.texture = item_icon

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and not is_minigame_active:
		if QuestManager.has_method("get_quest_status"):
			var quest_status = QuestManager.get_quest_status(target_quest_id)
			if quest_status != "ACTIVE":
				return

		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
			get_viewport().set_input_as_handled()
			start_chick_minigame()

func start_chick_minigame() -> void:
	var minigame_ui = get_tree().current_scene.find_child("RhythmMinigame", true, false)
	if minigame_ui:
		is_minigame_active = true
		
		if minigame_ui.minigame_completed.is_connected(_on_minigame_completed):
			minigame_ui.minigame_completed.disconnect(_on_minigame_completed)
			
		minigame_ui.minigame_completed.connect(_on_minigame_completed)
		minigame_ui.start_minigame()

func _on_minigame_completed(success: bool) -> void:
	is_minigame_active = false
	
	if success:
		spawn_and_add_chick_follower()
	else:
		is_player_inside = true

func spawn_and_add_chick_follower() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	
	if chick_scene and player:
		var new_chick = chick_scene.instantiate() as Node2D
		get_tree().current_scene.add_child(new_chick)
		new_chick.global_position = global_position
		
		if player.has_method("add_follower"):
			player.add_follower(new_chick)

	if GameManager.has_method("add_follower_data"):
		GameManager.add_follower_data()

	if GameManager.has_method("collect_item"):
		GameManager.collect_item(item_id)

	if QuestManager.has_method("add_quest_progress"):
		QuestManager.add_quest_progress(target_quest_id, 1)

	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		is_player_inside = true
		if QuestManager.has_method("get_quest_status"):
			if QuestManager.get_quest_status(target_quest_id) == "ACTIVE":
				start_hover_animation()
		else:
			start_hover_animation()

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		is_player_inside = false
		stop_hover_animation()

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
