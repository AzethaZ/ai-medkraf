extends Node2D

@export var cam_limit_left: int = -100
@export var cam_limit_right: int = 450
@export var cam_limit_top: int = -290
@export var cam_limit_bottom: int = 120

func _ready() -> void:
	var cam := get_node_or_null("Player/Camera2D") as Camera2D
	if cam:
		cam.limit_left = cam_limit_left
		cam.limit_right = cam_limit_right
		cam.limit_top = cam_limit_top
		cam.limit_bottom = cam_limit_bottom
		cam.reset_smoothing()
