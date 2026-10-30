extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Pastikan saat game mulai, layar hitam transparan
	color_rect.color.a = 0.0

func fade_out() -> void:
	animation_player.play("fade_to_black")
	await animation_player.animation_finished

func fade_in() -> void:
	animation_player.play("fade_from_black")
	await animation_player.animation_finished
