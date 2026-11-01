extends CharacterBody2D

@onready var dialogue_ui: Control = $DialogueUI
@onready var dialogue_label: Label = $DialogueUI/PanelContainer/VBoxContainer/Label

signal dialogue_finished

func show_chase_dialogue(text_content: String) -> void:
	if dialogue_ui and dialogue_label:
		dialogue_label.text = text_content
		dialogue_ui.visible = true

		# Menunggu pemain menekan tombol "interact" (E) untuk menutup dialog
		while true:
			await get_tree().process_frame
			if Input.is_action_just_pressed("interact"):
				break

		dialogue_ui.visible = false
		dialogue_finished.emit()
