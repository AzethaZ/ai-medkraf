extends Control

@export var image_1: Texture2D
@export var image_2: Texture2D
@export var image_3: Texture2D
@export var image_4: Texture2D

@onready var display_image: TextureRect = $DisplayImage
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var interact_icon: Node2D = find_child("InteractIcon", true, false)

var current_step: int = 1
var can_interact: bool = false
var target_next_scene: String = "res://scene/World/world_hutanbakar2.tscn"

# Variabel untuk animasi hover
var hover_tween: Tween = null
var base_icon_y: float = 0.0

func _ready() -> void:
	if not ResourceLoader.exists(target_next_scene):
		target_next_scene = "res://scene/world/world_hutanbakar2.tscn"

	# Buka layar dari SceneTransition global
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# Simpan koordinat Y asli InteractIcon dari Editor
	if interact_icon:
		base_icon_y = interact_icon.position.y
		interact_icon.visible = false

	fade_overlay.visible = true
	fade_overlay.color.a = 1.0

	# Mulai Tampilkan Gambar 1
	start_cutscene()

func start_cutscene() -> void:
	display_image.texture = image_1
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.6)
	await tween.finished
	
	# Aktifkan interaksi untuk ke Gambar 2
	enable_interaction()

func _unhandled_input(event: InputEvent) -> void:
	if can_interact and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
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

	# Kembalikan ke titik Y dasar
	interact_icon.position.y = base_icon_y

	# Buat Tween looping naik-turun
	hover_tween = create_tween().set_loops()

	# Melayang naik 6 piksel
	hover_tween.tween_property(interact_icon, "position:y", base_icon_y - 6.0, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Kembali turun ke posisi awal
	hover_tween.tween_property(interact_icon, "position:y", base_icon_y, 0.6)\
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
			# GAMBAR 1 KE GAMBAR 2: TANPA FADE (INSTAN)
			display_image.texture = image_2
			enable_interaction()

		3:
			# GAMBAR 2 KE GAMBAR 3: FADE TRANSITION
			await do_fade_transition(image_3)
			enable_interaction()

		4:
			# GAMBAR 3 KE GAMBAR 4: FADE TRANSITION
			await do_fade_transition(image_4)
			enable_interaction()

		5:
			disable_interaction()
			# 1. Layar Cutscene menggelap ke hitam
			if SceneTransition and SceneTransition.has_method("fade_out"):
				await SceneTransition.fade_out()
			else:
				var fade_out_tween = create_tween()
				fade_out_tween.tween_property(fade_overlay, "color:a", 1.0, 0.8)
				await fade_out_tween.finished

			# 2. Pindah ke scene world_hutanbakar2 (layar saat ini masih hitam pekat)
			get_tree().change_scene_to_file(target_next_scene)

func do_fade_transition(next_texture: Texture2D) -> void:
	# Fade Out ke Hitam
	var tween_out = create_tween()
	tween_out.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	await tween_out.finished

	# Ganti Gambar
	display_image.texture = next_texture

	# Fade In ke Terang
	var tween_in = create_tween()
	tween_in.tween_property(fade_overlay, "color:a", 0.0, 0.5)
	await tween_in.finished
