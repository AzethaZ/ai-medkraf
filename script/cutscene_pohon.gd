extends Control

@export var image_1: Texture2D
@export var image_2: Texture2D
@export var image_3: Texture2D

@onready var display_image: TextureRect = $DisplayImage
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var interact_icon: Sprite2D = $InteractIcon
@onready var particles: GPUParticles2D = $GPUParticles2D

var current_step: int = 1
var can_interact: bool = false
var target_next_scene: String = "res://scene/World/world_hutanbakar2.tscn"

# Variabel untuk animasi hover
var hover_tween: Tween
var base_icon_y: float = 0.0

func _ready() -> void:
	# Memutar musik cutscene dari awal scene muncul
	if MusicManager.has_method("play_cutscene_music"):
		var cutscene_track = load("res://assets/Audio/cutscene_cutscene.ogg")
		MusicManager.play_cutscene_music(cutscene_track, 12.0, 2.5)
		
	# Mendaftarkan target next_scene_name
	target_next_scene = "res://scene/World/world_hutanbakar2.tscn"
	
	# Fade in saat masuk ke scene ini
	if SceneTransition and SceneTransition.has_method("fade_in"):
		SceneTransition.fade_in()
		
	# Simpan koordinat Y asli InteractIcon dan hide
	if interact_icon:
		base_icon_y = interact_icon.position.y
		interact_icon.visible = false
		
	# Pastikan partikel mati di awal (saat Image 1 tampil)
	if particles:
		particles.emitting = false
		particles.visible = false
		
	fade_overlay.visible = true
	fade_overlay.color.a = 1.0
	
	# Mulai tampilan Gambar 1
	start_cutscene()

func start_cutscene() -> void:
	display_image.texture = image_1
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.8)
	await tween.finished
	
	# Aktifkan tombol untuk lanjut ke Gambar 2
	enable_interaction()

func _unhandled_input(event: InputEvent) -> void:
	if can_interact and event.is_action_pressed("interact"):
		disable_interaction()
		advance_cutscene()

# --- UTILITAS INTERAKSI & ANIMASI HOVER ---

func enable_interaction() -> void:
	can_interact = true
	if interact_icon:
		interact_icon.visible = true
		start_hover_animation()

func disable_interaction() -> void:
	can_interact = false
	if interact_icon:
		interact_icon.visible = false
		stop_hover_animation()

func start_hover_animation() -> void:
	if not interact_icon:
		return
		
	if hover_tween and hover_tween.is_running():
		hover_tween.kill()
		
	# Kembalikan ke titik dasar
	interact_icon.position.y = base_icon_y
	
	# Buat tween looping naik turun
	hover_tween = create_tween().set_loops()
	
	# Melayang naik 4 pixel
	hover_tween.tween_property(interact_icon, "position:y", base_icon_y - 4.0, 0.4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	# Kembali turun ke posisi awal
	hover_tween.tween_property(interact_icon, "position:y", base_icon_y, 0.4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func stop_hover_animation() -> void:
	if hover_tween and hover_tween.is_running():
		hover_tween.kill()

# --- ALUR CUTSCENE ---

func advance_cutscene() -> void:
	current_step += 1
	
	match current_step:
		2:
			# GAMBAR 1 KE GAMBAR 2: FADE TRANSITION
			await do_fade_transition(image_2, true)
			enable_interaction()
			
		3:
			# GAMBAR 2 KE GAMBAR 3: FADE TRANSITION
			await do_fade_transition(image_3, true)
			enable_interaction()
			
		4:
			disable_interaction()
			# 1. Transisi layar menggelap ke hitam
			if SceneTransition and SceneTransition.has_method("fade_out"):
				await SceneTransition.fade_out()
			else:
				var fade_out_tween = create_tween()
				fade_out_tween.tween_property(fade_overlay, "color:a", 1.0, 0.8)
				await fade_out_tween.finished
				
			# 2. Pindah ke scene world_hutanbakar2 (Layar saat ini masih hitam pekat)
			get_tree().change_scene_to_file(target_next_scene)

func do_fade_transition(next_texture: Texture2D, show_particles: bool = false) -> void:
	# Fade Out ke Hitam
	var tween_out = create_tween()
	tween_out.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	await tween_out.finished
	
	# Ganti Gambar & Atur Partikel
	display_image.texture = next_texture
	if particles:
		particles.visible = show_particles
		particles.emitting = show_particles
	
	# Fade In ke Terang
	var tween_in = create_tween()
	tween_in.tween_property(fade_overlay, "color:a", 0.0, 0.5)
	await tween_in.finished
