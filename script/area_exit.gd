extends Area2D

@export var is_back_door: bool = false
var is_player_inside: bool = false

# Ambil node Label yang baru dibuat
@onready var label: Label = $Label

func _ready() -> void:
	# Pastikan label tersembunyi saat awal game
	if label:
		label.visible = false
	
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and event.is_action_pressed("interact"):
		if is_back_door:
			GameManager.previous_level()
		else:
			GameManager.next_level()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_inside = true
		if label:
			label.visible = true # Tampilkan label saat Player masuk area

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_inside = false
		if label:
			label.visible = false # Sembunyikan label saat Player keluar area
