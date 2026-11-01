extends CanvasLayer

# 1. Pastikan path mengarah ke node tombol Start & Quit milikmu di Scene Tree
@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var exit_button: Button = $MarginContainer/VBoxContainer/ExitButton



# 2. Path scene cutscene awal game
@export_file("*.tscn") var first_scene: String = "res://scene/intro_cutscene.tscn"

func _ready() -> void:
	# Hubungkan sinyal klik tombol saat scene ready
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed() -> void:
	if SceneTransition.has_method("change_scene_to_file"):
		SceneTransition.change_scene_to_file(first_scene)
	elif SceneTransition.has_method("transition_to"):
		SceneTransition.transition_to(first_scene)
	else:
		get_tree().change_scene_to_file(first_scene)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
