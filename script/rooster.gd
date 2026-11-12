extends Area2D

@export var target_quest_id: String = "quest_ayam_3"

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
		
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
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

	# Memulai dialog pengantar sebelum bertarung
	DialogueManager.start_dialogue(dialogue_lines, player_ref)
	await DialogueManager.dialogue_finished

	is_in_dialogue = false
	start_transition_to_battle()


func start_transition_to_battle() -> void:
	is_minigame_active = true
	disable_player_movement(true)

	# Transisi layar gelap sebelum pindah ke arena pertempuran khusus
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
	else:
		await get_tree().create_timer(0.4).timeout

	# Pindah scene ke arena pertempuran rooster yang sudah di-zoom & diatur posisinya
	get_tree().change_scene_to_file("res://scene/Function/rooster_battle_arena.tscn")


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
