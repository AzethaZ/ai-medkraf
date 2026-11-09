extends CanvasLayer

# --- REFERENSI NODE UI ---
@onready var cutscene_image: TextureRect = $CutsceneImage
@onready var interact_icon: Sprite2D = $InteractIcon
@onready var color_rect: ColorRect = $ColorRect2

# --- REFERENSI NODE PIVOT & DIALOG BOX LOKAL ---
@onready var pivot_slide_1: Node2D = $Node2D/PivotSlide1 if has_node("Node2D/PivotSlide1") else null
@onready var cutscene_dialog_box: Node = $CutsceneDialogBox if has_node("CutsceneDialogBox") else null

# --- PRELOAD GAMBAR CUTSCENE ---
var cutscene_texture: Texture2D = preload("res://assets/cutscene/scene_13.png")

# --- DIALOGUE ---
var dialogue_text: String = "Danum pingsan dan tersungkur di antara pepohonan yang mengepul asap..."

# Tween untuk animasi hover
var hover_tween: Tween


func _ready() -> void:
	# 1. Sembunyikan InteractIcon saat awal masuk scene
	if interact_icon:
		interact_icon.hide()

	# 2. Pasang gambar scene_13
	if cutscene_image and cutscene_texture:
		cutscene_image.texture = cutscene_texture

	# 3. PASTIKAN AMBIENCE KEBAKARAN TETAP BERPUTAR DI LEVEL UTAMA
	if MusicManager and MusicManager.has_method("play_world_audio"):
		var ambience_track = load("res://assets/audio/kebakaran_ambience.mp3")
		# BGM diset null agar hanya ambience yang terdengar di cutscene ini
		MusicManager.play_world_audio(ambience_track, null, -12.0, 0.0)

	# 4. Fade In Layar (ColorRect2 di-tween dari hitam ke transparan)
	if color_rect:
		color_rect.color.a = 1.0
		var tween = create_tween()
		tween.tween_property(color_rect, "color:a", 0.0, 0.8)
		await tween.finished

	# 5. Fade In Global jika Autoload SceneTransition tersedia
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 6. Tampilkan Dialog
	trigger_dialogue(dialogue_text)

	# 7. Jalankan alur setelah dialog selesai
	start_post_dialogue_sequence()


func trigger_dialogue(text: String) -> void:
	if cutscene_dialog_box and cutscene_dialog_box.has_method("start_dialogue"):
		cutscene_dialog_box.start_dialogue([text], pivot_slide_1)
	elif cutscene_dialog_box and cutscene_dialog_box.has_method("show_text"):
		cutscene_dialog_box.show_text(text)
	elif DialogueManager:
		if DialogueManager.has_method("start_dialogue"):
			DialogueManager.start_dialogue([text], pivot_slide_1)
		elif DialogueManager.has_method("show_dialogue_text"):
			DialogueManager.show_dialogue_text(text, pivot_slide_1)


func start_post_dialogue_sequence() -> void:
	# Tunggu sinyal dialog selesai (atau timer fallback)
	if cutscene_dialog_box and cutscene_dialog_box.has_signal("dialogue_finished"):
		await cutscene_dialog_box.dialogue_finished
	elif DialogueManager and DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	else:
		await get_tree().create_timer(3.5).timeout

	# --- DIALOG SELESAI: TAMPILKAN INTERACT ICON HOVER ---
	if interact_icon:
		interact_icon.show()
		start_hover_animation()

	# Beri jeda 1.5 detik agar ikon terlihat sebelum bertransisi
	await get_tree().create_timer(1.5).timeout

	# --- EKSEKUSI FADE OUT AUDIO & PANDAH SCENE ---
	finish_cutscene()


# --- ANIMASI HOVER (NAIK TURUN) INTERACT ICON ---
func start_hover_animation() -> void:
	if not interact_icon:
		return
		
	if hover_tween and hover_tween.is_running():
		hover_tween.kill()

	var start_y = interact_icon.position.y
	hover_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_tween.tween_property(interact_icon, "position:y", start_y - 6.0, 0.5)
	hover_tween.tween_property(interact_icon, "position:y", start_y, 0.5)


# --- FADE OUT LAYAR & AUDIO SAMPAI HABIS SEBELUM BERPINDAH ---
func finish_cutscene() -> void:
	# 1. Hentikan animasi hover
	if hover_tween:
		hover_tween.kill()

	# 2. Fade Out Suara Ambience secara bertahap sampai habis (durasi 2 detik)
	if MusicManager and MusicManager.has_method("fade_out_audio"):
		MusicManager.fade_out_audio(2.0)

	# 3. Fade Out Layar (ColorRect2 di-tween ke Hitam pekat)
	if color_rect:
		var tween_fade = create_tween()
		tween_fade.tween_property(color_rect, "color:a", 1.0, 1.5)
		await tween_fade.finished

	# 4. Fade Out Global (SceneTransition Autoload) jika ada
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()

	# 5. Pindah ke Scene world_langit.tscn
	var target_scene = "res://scene/World/world_langit.tscn"
	if not ResourceLoader.exists(target_scene):
		target_scene = "res://scene/world_langit.tscn"

	get_tree().change_scene_to_file(target_scene)
