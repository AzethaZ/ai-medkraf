extends CanvasLayer

@onready var item_container: GridContainer = $Control/VBoxContainer/NinePatchRect/MarginContainer/GridContainer

func _ready() -> void:
	# Sembunyikan UI inventaris saat game baru dimulai
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		print("Tombol I berhasil ditekan!") # Tambahkan ini untuk tes
		visible = !visible
		print("Status visible saat ini: ", visible)
		if visible:
			update_inventory_ui()

func update_inventory_ui() -> void:
	for child in item_container.get_children():
		child.queue_free()
		
	for item_data in GameManager.inventory:
		var icon_rect = TextureRect.new()
		icon_rect.texture = item_data["icon"]
		
		# Pengaturan scaling gambar agar proporsional
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# NAIKKAN UKURAN DI SINI
		# Coba ubah dari 16x16 / 32x32 menjadi 50x50 atau 60x60
		icon_rect.custom_minimum_size = Vector2(64, 64)
		
		item_container.add_child(icon_rect)
