extends Area2D

# Export variabel agar target scene dan spawn point bisa diatur via Inspector
@export_file("*.tscn") var target_scene_path: String = "res://scene/World/world_1.tscn"
@export var target_spawn_id: String = ""

@export var requires_interaction: bool = true

# --- TAMBAHAN UNTUK PENGUNCIAN QUEST ---
@export var required_quest_id: String = ""
@export var required_quest_status: String = "COMPLETED"

@onready var interact_icon: Sprite2D = $InteractIcon if has_node("InteractIcon") else null

var is_player_inside: bool = false
var is_transitioning: bool = false
var tween: Tween = null
var base_icon_y: float = 0.0

func _ready() -> void:
	if interact_icon:
		base_icon_y = interact_icon.position.y
		interact_icon.visible = false

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if requires_interaction and is_player_inside and not is_transitioning and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		is_transitioning = true
		change_level()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_inside = true
		if interact_icon:
			interact_icon.visible = true
			start_hover_animation()

		# Jika mode TANPA interaksi (tinggal jalan ke kanan), langsung picu pindah scene
		if not requires_interaction and not is_transitioning:
			is_transitioning = true
			change_level()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_inside = false
		if interact_icon:
			interact_icon.visible = false
			stop_hover_animation()

func start_hover_animation() -> void:
	if not interact_icon:
		return
	if tween and tween.is_running():
		tween.kill()

	interact_icon.position.y = base_icon_y
	tween = create_tween().set_loops()
	tween.tween_property(interact_icon, "position:y", base_icon_y - 4.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(interact_icon, "position:y", base_icon_y, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()

# --- LOGIKA PINDAH SCENE AMAN ---

func change_level() -> void:
	# 1. PENGECEKAN SYARAT QUEST (TAMBAHAN)
	if required_quest_id != "":
		var current_status = QuestManager.get_quest_status(required_quest_id)
		if current_status != required_quest_status:
			print("Portal terkunci! Butuh quest '", required_quest_id, "' berstatus '", required_quest_status, "'. Status saat ini: ", current_status)
			is_transitioning = false # Reset status agar bisa dicoba lagi nanti
			return

	if interact_icon:
		interact_icon.visible = false
		stop_hover_animation()

	if target_scene_path.is_empty() or not ResourceLoader.exists(target_scene_path):
		print("ERROR: Target scene path tidak valid atau file tidak ditemukan: ", target_scene_path)
		is_transitioning = false
		return

	# Simpan target_spawn_id ke SceneTransition agar terbaca oleh scene tujuan
	if SceneTransition and "target_spawn_id" in SceneTransition:
		SceneTransition.target_spawn_id = target_spawn_id

	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(target_scene_path)
	elif SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		get_tree().change_scene_to_file(target_scene_path)
	else:
		get_tree().change_scene_to_file(target_scene_path)
