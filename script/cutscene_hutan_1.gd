extends CanvasLayer

@onready var cutscene_image: TextureRect = $CutsceneImage if has_node("CutsceneImage") else null
@onready var interact_icon: Sprite2D = $InteractIcon if has_node("InteractIcon") else null
@onready var color_rect_2: ColorRect = $ColorRect2 if has_node("ColorRect2") else null

# --- REFERENSI UI DIALOG BUBBLE INTERNAL CUTSCENE ---
@onready var cutscene_dialog_box: Control = $CutsceneDialogBox if has_node("CutsceneDialogBox") else null
@onready var cutscene_dialog_panel: PanelContainer = $CutsceneDialogBox/DialogueBox if has_node("CutsceneDialogBox/DialogueBox") else null
@onready var cutscene_dialog_label: Label = $CutsceneDialogBox/DialogueBox/VBoxContainer/MessageLabel if has_node("CutsceneDialogBox/DialogueBox/VBoxContainer/MessageLabel") else null
@onready var cutscene_next_indicator: TextureRect = $CutsceneDialogBox/DialogueBox/NextIndicator if has_node("CutsceneDialogBox/DialogueBox/NextIndicator") else null

# --- REFERENSI EXCLAMATION BOX ---
@onready var exclamation_box: PanelContainer = $CutsceneDialogBox/ExclamationBox if has_node("CutsceneDialogBox/ExclamationBox") else null
@onready var exclamation_label: Label = $CutsceneDialogBox/ExclamationBox/VBoxContainer/MessageLabel if has_node("CutsceneDialogBox/ExclamationBox/VBoxContainer/MessageLabel") else null
@onready var exclamation_next_indicator: TextureRect = $CutsceneDialogBox/ExclamationBox/NextIndicator if has_node("CutsceneDialogBox/ExclamationBox/NextIndicator") else null

# --- REFERENSI AUDIO ---
@onready var type_sound: AudioStreamPlayer = $TypeSound if has_node("TypeSound") else null
@onready var angry_sound: AudioStreamPlayer = $AngrySound if has_node("AngrySound") else null
@onready var angry_sound_2: AudioStreamPlayer = $AngrySound2 if has_node("AngrySound2") else null
@onready var fire_sound: AudioStreamPlayer = $FireSound if has_node("FireSound") else null
@onready var water_sound: AudioStreamPlayer = $WaterSound if has_node("WaterSound") else null
@onready var bush_sound: AudioStreamPlayer = $BushSound if has_node("BushSound") else null

# --- REFERENSI NODE PIVOT LOKASI BALON KATA ---
@onready var pivot_slide_1: Node = $Node2D/PivotSlide1 if has_node("Node2D/PivotSlide1") else null
@onready var pivot_slide_2: Node = $Node2D/PivotSlide2 if has_node("Node2D/PivotSlide2") else null
@onready var pivot_slide_3: Node = $Node2D/PivotSlide3 if has_node("Node2D/PivotSlide3") else null
@onready var pivot_slide_4: Node = $Node2D/PivotSlide4 if has_node("Node2D/PivotSlide4") else null

# Array memuat slide 5, 6, 7, dan 8
var slides: Array[Texture2D] = [
	preload("res://assets/cutscene_5.png"),
	preload("res://assets/cutscene/scene_6.png"),
	preload("res://assets/cutscene/scene_7.png"),
	preload("res://assets/cutscene_8.png")
]

var current_slide: int = 0
var is_transitioning: bool = false
var is_in_dialogue: bool = false
var tween_hover: Tween
var indicator_tween: Tween

var dialogues_per_slide: Dictionary = {}

func _ready() -> void:
	start_hover_animation()
	
	# PASTI KAN DUA NODE UI INI KEMBALI SEMBUNYI DI HARDIK AWAL FRAME 0
	if interact_icon:
		interact_icon.visible = false
	if cutscene_dialog_box:
		cutscene_dialog_box.visible = false
		cutscene_dialog_box.global_position = Vector2(-9999, -9999) # Pindahkan jauh keluar layar sebagai pertahanan ekstra
		
	# DAFTAR DIALOG SLIDE 1 - SLIDE 4
	dialogues_per_slide = {
		0: {
			"pivot": pivot_slide_1,
			"lines": ["!!!"]
		},
		1: {
			"pivot": pivot_slide_2,
			"lines": [
				"Bos, lahan ini dekat pemukiman adat...",
				"Bakar saja semuanya, jangan tinggalkan jejak!",
				"Tapi bagaimana dengan warga di sana...?"
			]
		},
		2: {
			"pivot": pivot_slide_3,
			"lines": ["!!!"]
		},
		3: {
			"pivot": pivot_slide_4,
			"lines": [
				"Siapa yang menyiram?",
				"Oii, anak kecil!"
			]
		}
	}
	
	# Aktifkan ColorRect2 untuk fade di awal scene
	if color_rect_2:
		color_rect_2.visible = true
		color_rect_2.modulate.a = 1.0
		
	show_slide(0)

	# FADE OUT MUSIK BGM AWAL
	if MusicManager:
		MusicManager.fade_out_audio(10.0)

	# FADE IN SUARA API PELAN DI SLIDE 1
	if fire_sound and fire_sound.stream:
		fire_sound.volume_db = -80.0
		fire_sound.play()
		var tween_fire_intro = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween_fire_intro.tween_property(fire_sound, "volume_db", -20.0, 2.0)
		
		# --- PLAY BUSH SOUND DI SLIDE 1 ---
	if bush_sound and bush_sound.stream:
		bush_sound.play()

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
	if is_transitioning or is_in_dialogue:
		return
		
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		next_slide()

func next_slide() -> void:
	if is_transitioning or is_in_dialogue:
		return
		
	current_slide += 1
	
	if current_slide < slides.size():
		change_slide_with_fade(current_slide)
	else:
		start_gameplay_2()

func change_slide_with_fade(next_index: int) -> void:
	is_transitioning = true
	
	# Sembunyikan UI sementara saat transisi
	if interact_icon:
		interact_icon.visible = false
	if cutscene_dialog_box:
		cutscene_dialog_box.visible = false
		
	if color_rect_2:
		color_rect_2.visible = true
		
		# --- TENTUKAN DURASI FADE ---
		# Durasi standar = 0.25s, Khusus ke Slide 3 (next_index == 2) = 0.9s (lebih lambat)
		var fade_out_time: float = 0.25
		var fade_in_time: float = 0.25
		
		if next_index == 2:
			fade_out_time = 0.9  # Fade menutup ke hitam dibuat lambat
			fade_in_time = 0.9   # Fade membuka terang dibuat lambat
		
		# 1. LAYAR ME-FADE OUT KE HITAM DULU (LAMBAT)
		var tween_out = create_tween()
		tween_out.tween_property(color_rect_2, "modulate:a", 1.0, fade_out_time)
		await tween_out.finished
		
		# ======================================================================
		# 2. SEKARANG LAYAR SUDAH GELAP HITAM PEKAT:
		# GANTI GAMBAR SLIDE + JALANKAN SFX & DIALOG DI DALAM KEGELAPAN
		# ======================================================================
		show_slide(next_index)
		
		# --- KONTROL SFX & DIALOG KHUSUS SLIDE 3 (next_index == 2) ---
		if next_index == 2:
			# Stop suara api
			if fire_sound and fire_sound.playing:
				fire_sound.stop()
				
			# Putar suara guyuran air & marah di balik layar hitam
			if water_sound and water_sound.stream:
				water_sound.play()
			if angry_sound_2 and angry_sound_2.stream:
				angry_sound_2.play()
				
			# Jalankan dialog Slide 3 di balik layar hitam
			if dialogues_per_slide.has(next_index):
				play_slide_dialogue(next_index)
				
			# Jeda tahanan hitam sejenak (0.6 detik) sebelum layar mulai mekar terang
			await get_tree().create_timer(0.6).timeout

		# --- KONTROL UNTUK SLIDE LAINNYA ---
		else:
			if next_index == 1 and fire_sound and fire_sound.playing:
				var fire_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				fire_tween.tween_property(fire_sound, "volume_db", -3.0, 1.2)
				
			if dialogues_per_slide.has(next_index):
				play_slide_dialogue(next_index)
		
		# ======================================================================
		# 3. ME-FADE IN TERANG KEMBALI MEMPERLIHATKAN SLIDE 3 (LAMBAT)
		# ======================================================================
		var tween_in = create_tween()
		tween_in.tween_property(color_rect_2, "modulate:a", 0.0, fade_in_time)
		await tween_in.finished
		color_rect_2.visible = false
		
	else:
		show_slide(next_index)
		if dialogues_per_slide.has(next_index):
			play_slide_dialogue(next_index)
		
	is_transitioning = false

func play_slide_dialogue(slide_index: int) -> void:
	is_in_dialogue = true
	
	if interact_icon:
		interact_icon.visible = false
		
	var data = dialogues_per_slide[slide_index]
	var target_pivot: Node = data["pivot"]
	var lines: Array = data["lines"]
	
	stop_indicator_anim()
		
	# 1. SEMBUNYIKAN DIALOG BOX TERLEBIH DAHULU KETIKA MENGATUR KOORDINAT BARU
	if cutscene_dialog_box:
		cutscene_dialog_box.visible = false

	if is_instance_valid(target_pivot):
		var target_pos: Vector2 = Vector2.ZERO
		if target_pivot is CanvasItem:
			target_pos = target_pivot.global_position
		else:
			target_pos = target_pivot.position
			
		if cutscene_dialog_box:
			cutscene_dialog_box.global_position = target_pos

	for line in lines:
		var active_panel: Control = cutscene_dialog_panel
		var active_label: Label = cutscene_dialog_label
		
		# Gunakan ExclamationBox (kotak kecil) jika teks berupa tanda seru (! / !! / !!!)
		if (line == "!" or line == "!!" or line == "!!!") and exclamation_box:
			active_panel = exclamation_box
			active_label = exclamation_label
			if cutscene_dialog_panel: cutscene_dialog_panel.hide()
			exclamation_box.show()
		else:
			active_panel = cutscene_dialog_panel
			active_label = cutscene_dialog_label
			if exclamation_box: exclamation_box.hide()
			if cutscene_dialog_panel: cutscene_dialog_panel.show()
		
		if active_label:
			active_label.text = line
			active_label.visible_characters = 0
			
		if active_panel:
			if active_panel.has_method("reset_size"):
				active_panel.reset_size()
			active_panel.pivot_offset = Vector2(active_panel.size.x / 2.0, active_panel.size.y)
			active_panel.position = Vector2(-active_panel.size.x / 2.0, -active_panel.size.y)
			active_panel.scale = Vector2(0.7, 0.3)
		
		# 2. SELESAIKAN PROCESS FRAME AGAR GODOT MENYELARASKAN POSISI DAHULU
		await get_tree().process_frame

		# 3. BARU TAMPILKAN DIALOG BOX TEPAT DI LOKASI TARGET PIVOT
		if cutscene_dialog_box:
			cutscene_dialog_box.visible = true

# TWEEN SHAKE MARAH: GOYANGAN DIPERLAMA & LEBIH DURATIF
		var is_angry_line: bool = ("Bakar saja semuanya" in line)
		if is_angry_line and active_panel:
			var base_pos = active_panel.position
			
			# 1. Pop Up Hentakan Membesar 135%
			active_panel.scale = Vector2(1.35, 1.35)
			var pop_tween = create_tween()
			pop_tween.tween_property(active_panel, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
			# 2. Guncangan Posisi Diperlama (Total Durasi ~0.8 Detik)
			var shake_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			shake_tween.tween_property(active_panel, "position", base_pos + Vector2(-14, 7), 0.12)
			shake_tween.tween_property(active_panel, "position", base_pos + Vector2(14, -9), 0.12)
			shake_tween.tween_property(active_panel, "position", base_pos + Vector2(-12, -6), 0.11)
			shake_tween.tween_property(active_panel, "position", base_pos + Vector2(10, 7), 0.11)
			shake_tween.tween_property(active_panel, "position", base_pos + Vector2(-8, -4), 0.10)
			shake_tween.tween_property(active_panel, "position", base_pos + Vector2(6, 4), 0.09)
			shake_tween.tween_property(active_panel, "position", base_pos + Vector2(-3, -2), 0.08)
			shake_tween.tween_property(active_panel, "position", base_pos, 0.07)
			
			if angry_sound and angry_sound.stream:
				angry_sound.play()
		else:
			if active_panel:
				var box_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				box_tween.tween_property(active_panel, "scale", Vector2(1.0, 1.0), 0.15)
				await box_tween.finished

		# ANIMASI TYPING TEXT
		var total_chars = line.length()
		for i in range(1, total_chars + 1):
			if active_label:
				active_label.visible_characters = i
			
			var is_first_char = (i == 1)
			var is_new_word = (i > 1 and line[i - 2] == " " and line[i - 1] != " ")
			
			if (is_first_char or is_new_word) and line[i - 1] != "\n":
				if type_sound and type_sound.stream:
					type_sound.volume_db = -10.0
					type_sound.pitch_scale = randf_range(0.85, 1.25)
					type_sound.play()
					
			await get_tree().create_timer(0.015).timeout
			
		if active_label:
			active_label.visible_characters = -1
			
		start_indicator_anim()
		await wait_for_player_input()
		stop_indicator_anim()
		
		if active_panel:
			var close_tween = create_tween()
			close_tween.tween_property(active_panel, "scale", Vector2(0.7, 0.3), 0.08)
			await close_tween.finished

	cutscene_dialog_box.visible = false
	if interact_icon:
		interact_icon.visible = true
	is_in_dialogue = false

func wait_for_player_input() -> void:
	await get_tree().process_frame
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			break

func start_indicator_anim() -> void:
	stop_indicator_anim()
	
	var active_indicator: TextureRect = null
	if exclamation_box and exclamation_box.visible and exclamation_next_indicator:
		active_indicator = exclamation_next_indicator
	elif cutscene_dialog_panel and cutscene_dialog_panel.visible and cutscene_next_indicator:
		active_indicator = cutscene_next_indicator

	if not active_indicator:
		return

	active_indicator.visible = true
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_property(active_indicator, "visible", false, 0.01).set_delay(0.4)
	indicator_tween.tween_property(active_indicator, "visible", true, 0.01).set_delay(0.4)

func stop_indicator_anim() -> void:
	if indicator_tween and indicator_tween.is_valid():
		indicator_tween.kill()
	if cutscene_next_indicator:
		cutscene_next_indicator.visible = false
	if exclamation_next_indicator:
		exclamation_next_indicator.visible = false

func fade_in_screen() -> void:
	is_transitioning = true
	if color_rect_2:
		color_rect_2.visible = true
		color_rect_2.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(color_rect_2, "modulate:a", 0.0, 0.4)
		await tween.finished
		color_rect_2.visible = false
		
	if dialogues_per_slide.has(current_slide):
		play_slide_dialogue(current_slide)
	elif interact_icon:
		interact_icon.visible = true
		
	is_transitioning = false

func start_gameplay_2() -> void:
	is_transitioning = true
	
	# Fade out suara api jika sedang berputar
	if fire_sound and fire_sound.playing:
		var audio_tween = create_tween()
		audio_tween.tween_property(fire_sound, "volume_db", -80.0, 1.0)
	
	if GameManager:
		GameManager.advance_story(GameManager.StoryStep.GAMEPLAY_2_DIKEJAR)
		
	var target_scene = "res://scene/World/world_hutanbakar.tscn"
	
	if GameManager and GameManager.has_method("_change_world"):
		GameManager.call_deferred("_change_world", target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)
