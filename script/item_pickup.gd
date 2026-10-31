extends Area2D

# 1. TAMBAHKAN baris export item_id ini di bagian paling atas
@export var item_id: String = "" 
@export var item_name: String = "Coin"
@export var item_icon: Texture2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var interact_icon: Sprite2D = $InteractIcon

var is_player_inside: bool = false
var tween: Tween
var initial_icon_y: float

func _ready() -> void:
	# 2. TAMBAHKAN pengecekan di _ready: jika item_id sudah tercatat di GameManager, hapus node ini
	if item_id != "" and GameManager.is_item_collected(item_id):
		queue_free()
		return

	if interact_icon:
		interact_icon.visible = false
		initial_icon_y = interact_icon.position.y

	if item_icon and sprite_2d:
		sprite_2d.texture = item_icon

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and event.is_action_pressed("interact"):
		pick_up()

# 3. SESUAIKAN fungsi pick_up() kamu untuk mencatat item_id sebelum queue_free()
func pick_up() -> void:
	# 1. Catat bahwa item dengan ID ini sudah pernah diambil (biar gak respawn)
	if item_id != "":
		GameManager.mark_item_collected(item_id)
	
	# 2. Bungkus ke dalam Dictionary lalu masukkan ke inventaris
	var item_data = {
		"name": item_name,
		"icon": item_icon
	}
	GameManager.add_item(item_data)
	
	# 3. Hapus item dari map
	queue_free()
	
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
