extends CharacterBody2D

@onready var dialogue_pivot: Marker2D = $DialoguePivot if has_node("DialoguePivot") else self

signal dialogue_finished

func show_chase_dialogue(text: String) -> void:
	if DialogueManager:
		# Argumen 1: Array teks dialog [text]
		# Argumen 2: Node pembicara (self)
		if DialogueManager.has_method("start_dialogue"):
			await DialogueManager.start_dialogue([text], self)
		elif DialogueManager.has_method("show_dialogue"):
			await DialogueManager.show_dialogue([text], self)
		
		# Tunggu hingga sinyal dialog selesai
		if DialogueManager.has_signal("dialogue_ended"):
			await DialogueManager.dialogue_ended
		elif DialogueManager.has_signal("dialogue_finished"):
			await DialogueManager.dialogue_finished
	else:
		await get_tree().create_timer(1.5).timeout

	dialogue_finished.emit()
