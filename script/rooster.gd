extends Area2D

@export var target_quest_id: String = "quest_ayam_3"
@export var rooster_qte_ui_scene: PackedScene = preload("res://scene/Function/rooster_qte_minigame.tscn")

@onready var interact_icon: Sprite2D = $InteractIcon if has_node("InteractIcon") else null

var is_player_inside: bool = false
var is_minigame_active: bool = false
var is_in_dialogue: bool = false
var player_ref: CharacterBody2D = null

var dialogue_lines: Array[String] = [
	"Akhirnya ketemu juga ayam jago ini...",
	"Mukanya galak banget, harus dikalahkan dulu nih!"
]

func _ready() -> void:
	if QuestManager.get_quest_status(target_quest_id) == "COMPLETED":
		queue_free()
		return

	if interact_icon:
		interact_icon.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and not is_minigame_active and not is_in_dialogue:
		if QuestManager.get_quest_status(target_quest_id) != "ACTIVE":
			return

		if event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			start_intro_dialogue()

func start_intro_dialogue() -> void:
	is_in_dialogue = true
	player_ref = get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D
	if not player_ref:
		is_in_dialogue = false
		return

	if interact_icon:
		interact_icon.visible = false

	disable_player_movement(true)

	DialogueManager.start_dialogue(dialogue_lines, player_ref)

	await DialogueManager.dialogue_finished

	is_in_dialogue = false
	start_transition_to_battle()

func start_transition_to_battle() -> void:
	is_minigame_active = true
	disable_player_movement(true)

	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
	else:
		await get_tree().create_timer(0.4).timeout

	if player_ref:
		var battle_center_x = (player_ref.global_position.x + global_position.x) / 2.0
		global_position.x = battle_center_x - 35.0
		player_ref.global_position.x = battle_center_x + 35.0
		global_position.y = player_ref.global_position.y

		var player_sprite = player_ref.find_child("AnimatedSprite2D", true, false)
		if player_sprite:
			player_sprite.flip_h = true

		var rooster_sprite = find_child("AnimatedSprite2D", true, false)
		if rooster_sprite:
			rooster_sprite.flip_h = false

	await get_tree().create_timer(0.2).timeout

	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	var qte_ui = get_tree().current_scene.find_child("RoosterQTEMinigame", true, false)
	if not qte_ui and rooster_qte_ui_scene:
		qte_ui = rooster_qte_ui_scene.instantiate()
		get_tree().current_scene.add_child(qte_ui)

	if qte_ui:
		if qte_ui.minigame_completed.is_connected(_on_qte_completed):
			qte_ui.minigame_completed.disconnect(_on_qte_completed)
		qte_ui.minigame_completed.connect(_on_qte_completed)

		if qte_ui.has_method("start_minigame"):
			qte_ui.start_minigame(player_ref)

func _on_qte_completed(success: bool) -> void:
	is_minigame_active = false

	if success:
		finish_rooster_quest()
	else:
		disable_player_movement(false)
		print("Gagal menaklukkan Ayam Jago! Coba lagi.")

func finish_rooster_quest() -> void:
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
	else:
		await get_tree().create_timer(0.4).timeout

	if QuestManager.has_method("add_quest_progress"):
		QuestManager.add_quest_progress(target_quest_id, 1)

	disable_player_movement(false)

	if SceneTransition and SceneTransition.has_method("fade_in"):
		SceneTransition.fade_in()

	queue_free()

func disable_player_movement(disable: bool) -> void:
	if not player_ref:
		player_ref = get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D

	if player_ref:
		if player_ref.has_method("set_dialogue_state"):
			player_ref.set_dialogue_state(disable)
		else:
			player_ref.set_physics_process(not disable)
			player_ref.set_process(not disable)

		if disable:
			player_ref.velocity = Vector2.ZERO

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_inside = true
		if QuestManager.get_quest_status(target_quest_id) == "ACTIVE" and interact_icon:
			interact_icon.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_inside = false
		if interact_icon:
			interact_icon.visible = false
		is_in_dialogue = false
