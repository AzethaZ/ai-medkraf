extends Node2D

@export var camera_limit_left: int = -480
@export var camera_limit_right: int = 1344

func _ready() -> void:
	var cam: Camera2D = _find_camera(self)
	if cam:
		cam.limit_left = camera_limit_left
		cam.limit_right = camera_limit_right

func _find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found:
			return found
	return null
