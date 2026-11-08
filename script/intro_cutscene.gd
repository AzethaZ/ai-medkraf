extends CanvasLayer

@onready var cutscene_image: TextureRect = $CutsceneImage
@onready var color_rect_2: ColorRect = $ColorRect2
@onready var interact_icon: Sprite2D = $InteractIcon

# --- REFERENSI UI DIALOG BUBBLE INTERNAL CUTSCENE ---
@onready var cutscene_dialog_box: Control = $CutsceneDialogBox if has_node("CutsceneDialogBox") else null
@onready var cutscene_dialog_panel: PanelContainer = $CutsceneDialogBox/DialogueBox if has_node("CutsceneDialogBox/DialogueBox") else null
@onready var cutscene_dialog_label: Label = $CutsceneDialogBox/DialogueBox/VBoxContainer/MessageLabel if has_node("CutsceneDialogBox/DialogueBox/VBoxContainer/MessageLabel") else null
@onready var cutscene_next_indicator: TextureRect = $CutsceneDialogBox/DialogueBox/NextIndicator if has_node("CutsceneDialogBox/DialogueBox/NextIndicator") else null

# --- REFERENSI EXCLAMATION BOX (KOTAK KECIL) ---
@onready var exclamation_box: PanelContainer = $CutsceneDialogBox/ExclamationBox if has_node("CutsceneDialogBox/ExclamationBox") else null
@onready var exclamation_label: Label = $CutsceneDialogBox/ExclamationBox/VBoxContainer/MessageLabel if has_node("CutsceneDialogBox/ExclamationBox/VBoxContainer/MessageLabel") else null
@onready var exclamation_next_indicator: TextureRect = $CutsceneDialogBox/ExclamationBox/NextIndicator if has_node("CutsceneDialogBox/ExclamationBox/NextIndicator") else null

# --- REFERENSI AUDIO ---
@onready var type_sound: AudioStreamPlayer = $TypeSound if has_node("TypeSound") else null
@onready var event_sfx: AudioStreamPlayer = $SlideSFX if has_node("SlideSFX") else null # Node untuk SFX peristiwa (Api, Air, dll)

# --- REFERENSI NODE PIVOT LOKASI BALON KATA ---
@onready var pivot_slide_1: Node = $Node2D/PivotSlide1 if has_node("Node2D/PivotSlide1") else null
@onready var pivot_slide_3: Node = $Node2D/PivotSlide3 if has_node("Node2D/PivotSlide3") else ($ChaserPivot if has_node("ChaserPivot") else null)
@onready var pivot_slide_4: Node = $Node2D/PivotSlide4 if has_node("Node2D/PivotSlide4") else null

# Path slide gambar cutscene
var slide_paths: Array[String] = [
	"res://assets/cutscene_1.png",
	"res://assets/cutscene_2.png",
	"res://assets/cutscene/scene_3.png",
	"res://assets/cutscene/scene_4.png"
]

var slides: Array[Texture2D] = []
var current_slide: int = 0
var is_transitioning: bool = false
var is_in_dialogue: bool = false
var tween_hover: Tween
var indicator_tween: Tween

# Format: index_slide: {"pivot": node_pivot, "lines": [{"text": "...", "sfx": "res://path_audio.wav"}]}
var dialogues_per_slide: Dictionary = {}

func _ready() -> void:
	load_slides()
	start_hover_animation()
	
	if interact_icon:
		interact_icon.visible = false
	if cutscene_dialog_box:
		cutscene_dialog_box.visible = false
		
	# --- PENGATURAN DIALOG & SFX PER BARIS/PERISTIWA ---
	dialogues_per_slide = {
		# Slide 0 / Scene 1 (Contoh: SFX Api Unggun)
		0: {
			"pivot": pivot_slide_1,
			"lines": [
				{
					"text": "Lihat api unggun itu... terlalu besar!",
					"sfx": "res://assets/audio/soundreality-fire-crackling-campfire-sound-575667.mp3" # <-- SFX API
				}
			]
		},
		# Slide 1 / Scene 2 (Contoh: SFX Menyiram Air)
		1: {
			"pivot": pivot_slide_3,
			"lines": [
				{
					"text": "Danum menyiramkan air untuk memadamkan apinya!",
					"sfx": "res://assets/audio/universfield-water-splash-199583.mp3" # <-- SFX AIR
				}
			]
		},
		# Slide 2 (Pengejaran)
		2: {
			"pivot": pivot_slide_3,
			"lines": [
				{
					"text": "Jangan lari kamu, Danum!",
					"sfx": ""
				}
			]
		},
		# Slide 3 (Kejutan)
		3: {
			"pivot": pivot_slide_4,
			"lines": [
				{
					"text": "!!",
					"sfx": "res://assets/audio/alert_sfx.wav"
				}
			]
		}
	}
	
	show_slide(0)
	fade_in_screen()

func load_slides() -> void:
	slides.clear()
	for path in slide_paths:
		if ResourceLoader.exists(path):
			slides.append(load(path))
		else:
			slides.append(null)

func start_hover_animation() -> void:
	if interact_icon:
		if tween_hover and tween_hover.is_running():
			tween_hover.kill()
		tween_hover = create_tween().set_loops()
		tween_hover.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
		tween_hover.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)

func show_slide(index: int) -> void:
	if index < slides.size() and cutscene_image and slides[index] != null:
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
		start_game()

func change_slide_with_fade(next_index: int) -> void:
	is_transitioning = true
	
	if interact_icon:
		interact_icon.visible = false
	if cutscene_dialog_box:
		cutscene_dialog_box.visible = false
		
	if color_rect_2:
		color_rect_2.visible = true
		var tween_out = create_tween()
		tween_out.tween_property(color_rect_2, "modulate:a", 1.0, 0.25)
		await tween_out.finished
		
		show_slide(next_index)
		
		var tween_in = create_tween()
		tween_in.tween_property(color_rect_2, "modulate:a", 0.0, 0.25)
		await tween_in.finished
		color_rect_2.visible = false
	else:
		show_slide(next_index)
		
	is_transitioning = false
	
	if dialogues_per_slide.has(next_index):
		play_slide_dialogue(next_index)
	else:
		if interact_icon:
			interact_icon.visible = true

func play_slide_dialogue(slide_index: int) -> void:
	is_in_dialogue = true
	
	if interact_icon:
		interact_icon.visible = false
		
	var data = dialogues_per_slide[slide_index]
	var target_pivot: Node = data["pivot"]
	var lines: Array = data["lines"]
	
	stop_indicator_anim()
		
	if is_instance_valid(target_pivot):
		var target_pos: Vector2 = Vector2.ZERO
		if target_pivot is CanvasItem:
			target_pos = target_pivot.global_position
		else:
			target_pos = target_pivot.position
			
		cutscene_dialog_box.global_position = target_pos

	for item in lines:
		var line_text: String = ""
		var sfx_path: String = ""
		
		# Membaca struktur Dictionary (Teks + SFX)
		if item is Dictionary:
			line_text = item.get("text", "")
			sfx_path = item.get("sfx", "")
		else:
			line_text = str(item)
			
		# Pemicu SFX Peristiwa (Api / Air / dll)
		if sfx_path != "" and ResourceLoader.exists(sfx_path) and event_sfx:
			event_sfx.stream = load(sfx_path)
			event_sfx.play()

		var active_panel: Control = cutscene_dialog_panel
		var active_label: Label = cutscene_dialog_label
		
		if line_text == "!!" and exclamation_box:
			active_panel = exclamation_box
			active_label = exclamation_label
			if cutscene_dialog_panel: cutscene_dialog_panel.hide()
			exclamation_box.show()
		else:
			active_panel = cutscene_dialog_panel
			active_label = cutscene_dialog_label
			if exclamation_box: exclamation_box.hide()
			if cutscene_dialog_panel: cutscene_dialog_panel.show()
		
		cutscene_dialog_box.visible = true
		
		if active_label:
			active_label.text = line_text
			active_label.visible_characters = 0
			
		if active_panel:
			if active_panel.has_method("reset_size"):
				active_panel.reset_size()
			active_panel.pivot_offset = Vector2(active_panel.size.x / 2.0, active_panel.size.y)
			active_panel.position = Vector2(-active_panel.size.x / 2.0, -active_panel.size.y)
			
			active_panel.scale = Vector2(0.7, 0.3)
			var box_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			box_tween.tween_property(active_panel, "scale", Vector2(1.0, 1.0), 0.2)
		
		var total_chars = line_text.length()
		for i in range(1, total_chars + 1):
			if active_label:
				active_label.visible_characters = i
			
			var is_first_char = (i == 1)
			var is_new_word = (i > 1 and line_text[i - 2] == " " and line_text[i - 1] != " ")
			
			if (is_first_char or is_new_word) and line_text[i - 1] != "\n":
				if type_sound:
					type_sound.volume_db = -12.0
					type_sound.pitch_scale = randf_range(0.75, 1.35)
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
		
	if interact_icon and not dialogues_per_slide.has(current_slide):
		interact_icon.visible = true
		
	is_transitioning = false

func start_game() -> void:
	is_transitioning = true
	if GameManager:
		GameManager.advance_story(GameManager.StoryStep.GAMEPLAY_1_HUTAN)
		
	var target_scene = "res://scene/World/world_hutanawal.tscn"
	if GameManager and GameManager.has_method("_change_world"):
		GameManager.call_deferred("_change_world", target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)
