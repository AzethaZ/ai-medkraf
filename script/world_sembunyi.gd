extends Node2D

func _ready() -> void:
	# Layar mulai me-fade in saat masuk scene sembunyi
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()
