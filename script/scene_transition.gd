extends CanvasLayer

var target_spawn_id: String = ""

@onready var color_rect: ColorRect = $ColorRect

func fade_out(duration: float = 0.5) -> void:
	color_rect.visible = true
	var tween = create_tween()
	await tween.tween_property(color_rect, "modulate:a", 1.0, duration).finished

func fade_in(duration: float = 0.5) -> void:
	var tween = create_tween()
	await tween.tween_property(color_rect, "modulate:a", 0.0, duration).finished
	color_rect.visible = false
