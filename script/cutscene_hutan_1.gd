extends CanvasLayer

@onready var cutscene_image: TextureRect = $CutsceneImage
@onready var interact_icon: Sprite2D = $InteractIcon
@onready var color_rect_2: ColorRect = $ColorRect2

# Array memuat slide 5, 6, 7, dan 8
var slides: Array[Texture2D] = [
	preload("res://assets/cutscene_5.png"),
	preload("res://assets/cutscene_6.png"),
	preload("res://assets/cutscene_7.png"),
	preload("res://assets/cutscene_8.png")
]

var current_slide: int = 0
var is_transitioning: bool = false
var tween_hover: Tween

func _ready() -> void:
	start_hover_animation()
	
	# Aktifkan ColorRect2 untuk efek fade di awal scene
	if color_rect_2:
		color_rect_2.visible = true
		color_rect_2.modulate.a = 1.0 # Mulai dari hitam pekat
	
	show_slide(0)
	fade_in_screen()

func start_hover_animation() -> void:
	if interact_icon:
		if tween_hover and tween_hover.is_running():
			tween_hover.kill()
		
		tween_hover = create_tween().set_loops()
		tween_hover.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
		tween_hover.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)

func show_slide(index: int) -> void:
	if index < slides.size() and cutscene_image:
		cutscene_image.texture = slides[index]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		next_slide()

func next_slide() -> void:
	if is_transitioning:
		return
		
	current_slide += 1
	
	if current_slide < slides.size():
		change_slide_with_fade(current_slide)
	else:
		start_gameplay_2()

# --- ANIMASI FADE ANTAR SLIDE ---

func change_slide_with_fade(next_index: int) -> void:
	is_transitioning = true
	
	if color_rect_2:
		color_rect_2.visible = true
		var tween = create_tween()
		
		# 1. Layar perlahan me-fade out ke hitam
		tween.tween_property(color_rect_2, "modulate:a", 1.0, 0.25)
		await tween.finished
		
		# 2. Ganti tekstur gambar saat layar hitam
		show_slide(next_index)
		
		# 3. Layar perlahan me-fade in terang kembali
		var tween_in = create_tween()
		tween_in.tween_property(color_rect_2, "modulate:a", 0.0, 0.25)
		await tween_in.finished
		color_rect_2.visible = false
	else:
		show_slide(next_index)
		
	is_transitioning = false

# Fade in saat scene cutscene baru pertama kali terbuka
func fade_in_screen() -> void:
	is_transitioning = true
	if color_rect_2:
		var tween = create_tween()
		tween.tween_property(color_rect_2, "modulate:a", 0.0, 0.4)
		await tween.finished
		color_rect_2.visible = false
	is_transitioning = false

func start_gameplay_2() -> void:
	is_transitioning = true
	
	# Update stage cerita ke GAMEPLAY_2_DIKEJAR
	if GameManager:
		GameManager.advance_story(GameManager.StoryStep.GAMEPLAY_2_DIKEJAR)
	
	var target_scene = "res://scene/World/world_hutanbakar.tscn"
	
	if GameManager and GameManager.has_method("_change_world"):
		GameManager.call_deferred("_change_world", target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)
