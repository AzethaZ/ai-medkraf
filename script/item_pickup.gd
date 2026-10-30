extends Area2D

@export var item_name: String = "Coin"
@export var item_icon: Texture2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var interact_icon: Sprite2D = $InteractIcon

var is_player_inside: bool = false
var tween: Tween
var initial_icon_y: float

func _ready() -> void:
	if interact_icon:
		interact_icon.visible = false
		initial_icon_y = interact_icon.position.y # Simpan posisi awal Y ikon
	
	if item_icon and sprite_2d:
		sprite_2d.texture = item_icon
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and event.is_action_pressed("interact"):
		pick_up()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_inside = true
		if interact_icon:
			interact_icon.visible = true
			start_hover_animation()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_inside = false
		if interact_icon:
			interact_icon.visible = false
			stop_hover_animation()

# --- FUNGSI EFEK NAIK TURUN (TWEEN) ---
func start_hover_animation() -> void:
	# Hentikan tween lama jika ada
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_loops() # set_loops() agar animasi berulang terus
	
	# Bergerak ke atas sebesar 4 piksel dalam waktu 0.6 detik
	tween.tween_property(interact_icon, "position:y", initial_icon_y - 4.0, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	# Kembali bergerak ke bawah ke posisi awal dalam 0.6 detik
	tween.tween_property(interact_icon, "position:y", initial_icon_y, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func stop_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
	# Kembalikan posisi Y ke semula
	if interact_icon:
		interact_icon.position.y = initial_icon_y

func pick_up() -> void:
	if GameManager.has_method("add_item"):
		GameManager.add_item({
			"name": item_name,
			"icon": sprite_2d.texture
		})
	queue_free()
