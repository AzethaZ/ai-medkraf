extends CanvasLayer

# Path mengarah ke folder Function
@export_file("*.tscn") var first_scene: String = "res://scene/Function/intro_narrative.tscn"

@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var exit_button: Button = $MarginContainer/VBoxContainer/ExitButton


func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_quit_button_pressed)


func _on_start_button_pressed() -> void:
	# Pindah ke scene intro narrative di dalam folder Function
	get_tree().change_scene_to_file("res://scene/Function/intro_narrative.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
