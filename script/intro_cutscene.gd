extends CanvasLayer

@onready var cutscene_image: TextureRect = $CutsceneImage
@onready var color_rect_2: ColorRect = $ColorRect2
@onready var interact_icon: Sprite2D = $InteractIcon # Disesuaikan ke Sprite2D

var tween_hover: Tween

var slides: Array[Texture2D] = [
	preload("res://assets/IGI Cutscene1.png"),
	preload("res://assets/IGI Cutscene2.png"),
	preload("res://assets/IGI Cutscene3.png")
]

var current_slide: int = 0
var is_transitioning: bool = false

func _ready() -> void:
	if color_rect_2:
		color_rect_2.visible = true
		color_rect_2.modulate.a = 1.0
	
	# Jalankan animasi hover melayang untuk ikon panah/interact
	start_hover_animation()
	
	show_slide(0)

# Fungsi animasi hover naik-turun persis seperti di NPC 2
func start_hover_animation() -> void:
	if interact_icon:
		if tween_hover and tween_hover.is_running():
			tween_hover.kill()
		
		tween_hover = create_tween().set_loops()
		tween_hover.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween_hover.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_transitioning:
			return
		next_slide()

func show_slide(index: int) -> void:
	is_transitioning = true
	cutscene_image.texture = slides[index]
	
	var tween = create_tween()
	tween.tween_property(color_rect_2, "modulate:a", 0.0, 0.6)
	await tween.finished
	
	is_transitioning = false

func next_slide() -> void:
	current_slide += 1
	
	if current_slide < slides.size():
		is_transitioning = true
		
		var tween = create_tween()
		tween.tween_property(color_rect_2, "modulate:a", 1.0, 0.4)
		await tween.finished
		
		show_slide(current_slide)
	else:
		start_game()

func start_game() -> void:
	is_transitioning = true
	
	# Matikan animasi hover saat scene selesai
	if tween_hover:
		tween_hover.kill()
		
	var tween = create_tween()
	tween.tween_property(color_rect_2, "modulate:a", 1.0, 0.6)
	await tween.finished
	
	get_tree().change_scene_to_file("res://scene/World/world_1.tscn")
