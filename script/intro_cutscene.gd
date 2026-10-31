extends CanvasLayer

@onready var cutscene_image: TextureRect = $CutsceneImage
@onready var color_rect_2: ColorRect = $ColorRect2 # ColorRect hitam penyedia efek fade

var slides: Array[Texture2D] = [
	preload("res://assets/IGI Cutscene1.png"),
	preload("res://assets/IGI Cutscene2.png"),
	preload("res://assets/IGI Cutscene3.png")
]

var current_slide: int = 0
var is_transitioning: bool = false

func _ready() -> void:
	# Pastikan ColorRect2 menutup layar di awal (hitam pekat) untuk efek Fade In awal
	if color_rect_2:
		color_rect_2.visible = true
		color_rect_2.modulate.a = 1.0
	
	show_slide(0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_transitioning:
			return
		next_slide()

func show_slide(index: int) -> void:
	is_transitioning = true
	cutscene_image.texture = slides[index]
	
	# Fade In: Layar perlahan terbuka dari hitam ke terang
	var tween = create_tween()
	tween.tween_property(color_rect_2, "modulate:a", 0.0, 0.6)
	await tween.finished
	
	is_transitioning = false

func next_slide() -> void:
	current_slide += 1
	
	if current_slide < slides.size():
		is_transitioning = true
		
		# Fade Out antar slide (layar menghitam sebentar)
		var tween = create_tween()
		tween.tween_property(color_rect_2, "modulate:a", 1.0, 0.4)
		await tween.finished
		
		show_slide(current_slide)
	else:
		start_game()

func start_game() -> void:
	is_transitioning = true
	
	# Fade Out akhir: Layar perlahan menghitam total sebelum pindah scene
	var tween = create_tween()
	tween.tween_property(color_rect_2, "modulate:a", 1.0, 0.6)
	await tween.finished
	
	# Pindah ke scene world_1
	get_tree().change_scene_to_file("res://scene/World/world_1.tscn")
