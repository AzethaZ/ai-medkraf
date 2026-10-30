extends Area2D

# Properti yang bisa diubah langsung dari Inspector
@export var item_name: String = "Coin"
@export var item_icon: Texture2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var interact_label: Label = $Label

var is_player_inside: bool = false

func _ready() -> void:
	if interact_label:
		interact_label.visible = false
	
	# Pasang gambar sprite dari Inspector jika diisi
	if item_icon and sprite_2d:
		sprite_2d.texture = item_icon
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and event.is_action_pressed("interact"):
		pick_up()

func _on_body_entered(body: Node2D) -> void:
	if body is Player: # Pastikan nama class player kamu sesuai
		is_player_inside = true
		if interact_label:
			interact_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_inside = false
		if interact_label:
			interact_label.visible = false

func pick_up() -> void:
	print("Item diambil: ", item_name)
	
	# Ambil texture/gambar dari Sprite2D
	var texture_to_save = sprite_2d.texture
	
	# Simpan dictionary berisi nama dan ikon ke GameManager
	if GameManager.has_method("add_item"):
		GameManager.add_item({
			"name": item_name,
			"icon": texture_to_save
		})
	
	queue_free()
