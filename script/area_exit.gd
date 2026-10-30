extends Area2D

@export var is_back_door: bool = false
var is_player_inside: bool = false

# Ambil node Label yang baru dibuat
@onready var interact_icon: Sprite2D = $InteractIcon
var tween: Tween

func _ready() -> void:
	# Pastikan label tersembunyi saat awal game
	if interact_icon:
		interact_icon.visible = false
	
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
		if interact_icon:
			interact_icon.visible = true
			start_hover_animation() # Panggil animasi melayang

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_inside = false
		if interact_icon:
			interact_icon.visible = false
			stop_hover_animation() # Hentikan animasi

# --- FUNGSI EFEK NAIK TURUN (TWEEN) ---
func start_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_loops()
	
	# Naik 4 piksel relatif
	tween.tween_property(interact_icon, "position:y", -4.0, 0.6)\
		.as_relative()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	# Turun 4 piksel relatif kembali
	tween.tween_property(interact_icon, "position:y", 4.0, 0.6)\
		.as_relative()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func stop_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
