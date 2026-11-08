extends Area2D

# Diisi path scene cutscene ke-2 (Cutscene Bakar Hutan)
@export_file("*.tscn") var next_cutscene: String = "res://scene/Function/cutscene_hutan_1.tscn"

@onready var interact_icon: Sprite2D = $InteractIcon

var is_player_inside: bool = false
var has_been_triggered: bool = false
var hover_tween: Tween

func _ready() -> void:
	if interact_icon:
		interact_icon.visible = false
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func start_hover_animation() -> void:
	if not interact_icon:
		return
		
	stop_hover_animation()
	
	# Animasi melayang naik-turun halus (hover)
	hover_tween = create_tween().set_loops()
	hover_tween.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
	hover_tween.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)

func stop_hover_animation() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and not has_been_triggered and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		trigger_bakar_hutan_cutscene()

func trigger_bakar_hutan_cutscene() -> void:
	has_been_triggered = true
	stop_hover_animation()
	
	if interact_icon:
		interact_icon.visible = false
		
	# Update stage cerita ke GameManager
	if GameManager:
		GameManager.advance_story(GameManager.StoryStep.CUTSCENE_HUTAN_1)
		
	# Gunakan _change_world milik GameManager atau bawaan Godot get_tree()
	if GameManager and GameManager.has_method("_change_world"):
		GameManager.call_deferred("_change_world", next_cutscene)
	else:
		get_tree().change_scene_to_file(next_cutscene)

func _on_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.name == "Player") and not has_been_triggered:
		is_player_inside = true
		if interact_icon:
			interact_icon.visible = true
			start_hover_animation()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_inside = false
		stop_hover_animation()
		if interact_icon:
			interact_icon.visible = false
