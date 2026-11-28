extends Node2D

@export var wing_flap_interval: float = 10.0
@export var wing_pitch_min: float = 0.5
@export var wing_pitch_max: float = 0.9

@export var pan_offset: Vector2 = Vector2(430.0, 260.0)
@export var pan_duration: float = 20.0
@export var bg_2_fade_duration: float = 2.5
@export var cloud_hold_duration: float = 1.5
@export var bg_3_reveal_duration: float = 1.8
@export var bg_3_pan_duration: float = 5.0

@export var bird_enter_offset: Vector2 = Vector2(45.0, 30.0)
@export var bird_start_scale_multiplier: float = 1.25
@export var bird_enter_duration: float = 4.0
@export var initial_black_delay: float = 1.2

# Pengaturan fade-out BGM dari world sebelumnya
@export var bgm_fade_out_duration: float = 2.5

@onready var camera_2d: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var landscape_1: Parallax2D = $LandscapeParallax if has_node("LandscapeParallax") else null
@onready var landscape_2: Parallax2D = $LandscapeParallax2 if has_node("LandscapeParallax2") else null
@onready var landscape_3: Parallax2D = $LandscapeParallax3 if has_node("LandscapeParallax3") else null
@onready var burung_sprite: Sprite2D = $BurungSprite if has_node("BurungSprite") else null
@onready var burung_sprite_2: Sprite2D = $BurungSprite2 if has_node("BurungSprite2") else null
@onready var pivot_danum: Node2D = $BurungSprite/PivotDanum if has_node("BurungSprite/PivotDanum") else null
@onready var pivot_enggang: Node2D = $BurungSprite/PivotEnggang if has_node("BurungSprite/PivotEnggang") else null
@onready var wing_flap_sfx: AudioStreamPlayer = $WingFlapSFX if has_node("WingFlapSFX") else null
@onready var fire_ambience_sfx: AudioStreamPlayer = $FireAmbienceSFX if has_node("FireAmbienceSFX") else null

@export var thailand_bgm: AudioStream
@export var thailand_bgm_db: float = -12.0
const VIETNAM_BGM := preload("res://assets/animation/pop.mp3")
@export var vietnam_bgm_delay: float = 1.5 # Atur lama delay dalam detik sesuai selera
var bg2_fade_tween: Tween
var is_flapping: bool = false


# --- NASKAH DIALOG CUTSCENE DENGAN PENANDA TRANSISI ---
var cutscene_dialogues: Array[Dictionary] = [
	{"speaker": "Danum", "text": "Kita terbang ke mana lagi sekarang, Enggang?"},
	{"speaker": "Enggang", "text": "Kita menuju kawasan hutan di Thailand, Danum. Ada sebuah penginapan unik yang tersembunyi di antara pepohonan.", "trigger_bg2": true},
	{"speaker": "Danum", "text": "Hutan di sini terasa sangat rimbun dan sejuk sekali dari atas awan."},
	{"speaker": "Enggang", "text": "Sebentar lagi kita sampai. Coba perhatikan celah di antara tajuk-tajuk pohon di bawah sana."},
	{"speaker": "Danum", "text": "Lihat di bawah sana! Bangunan penginapannya unik sekali, bentuknya menyerupai sarang burung!", "trigger_bg3": true},
	{"speaker": "Enggang", "text": "Betul. Penginapan itu dibangun menyesuaikan kondisi alam sekitar, sehingga para tamu bisa menikmati suasana hutan tanpa merusaknya."},
	{"speaker": "Danum", "text": "Wah, menarik sekali! Tapi... sepertinya area di sekitar penginapan terlihat agak berantakan setelah hujan."},
	{"speaker": "Enggang", "text": "Ayo kita turun ke sana! Siapa tahu pengelola penginapan membutuhkan bantuan kita untuk merapikannya."}
]

func _ready() -> void:
	get_tree().paused = false

	# Mulai fade-out BGM dari world sebelumnya (setelah quest peternak beres)
	_fade_out_previous_bgm()

	if fire_ambience_sfx:
		fire_ambience_sfx.stop()

	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()

	if landscape_1:
		landscape_1.visible = true
		landscape_1.modulate.a = 1.0
	if landscape_2:
		landscape_2.visible = true
		landscape_2.modulate.a = 0.0
	if landscape_3:
		landscape_3.visible = true
		landscape_3.modulate.a = 0.0

	_start_wing_flap_loop()
	_prepare_bird_entrance()
	_prepare_diagonal_pan()

	_play_bird_entrance()
	_play_diagonal_pan()

	await _play_initial_black_screen()

	await get_tree().create_timer(0.5).timeout
	await _play_cutscene_dialogue()

	await get_tree().create_timer(1.2).timeout

	is_flapping = false
	if wing_flap_sfx and wing_flap_sfx.playing:
		var sfx_tween := create_tween()
		sfx_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		sfx_tween.tween_property(wing_flap_sfx, "volume_db", -40.0, 0.8)
		await sfx_tween.finished
		wing_flap_sfx.stop()

	get_tree().paused = false

	var next_scene_path := "res://scene/World/world_6.tscn"
	if not ResourceLoader.exists(next_scene_path):
		push_error("File scene tidak ditemukan: " + next_scene_path)
		return

	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(next_scene_path)
	else:
		get_tree().change_scene_to_file(next_scene_path)

func _fade_out_previous_bgm() -> void:
	if not MusicManager:
		return
	
	var is_ambience_playing: bool = MusicManager.ambience_player and MusicManager.ambience_player.playing
	var is_bgm_playing: bool = MusicManager.bgm_player and MusicManager.bgm_player.playing
	
	if (is_ambience_playing or is_bgm_playing) and MusicManager.has_method("fade_out_audio"):
		MusicManager.fade_out_audio(2.5)

func _start_wing_flap_loop() -> void:
	if not wing_flap_sfx:
		return
	is_flapping = true
	_trigger_wing_flap()

func _trigger_wing_flap() -> void:
	if not is_flapping or not is_inside_tree() or not wing_flap_sfx:
		return
	wing_flap_sfx.pitch_scale = randf_range(wing_pitch_min, wing_pitch_max)
	wing_flap_sfx.play()
	get_tree().create_timer(wing_flap_interval).timeout.connect(_trigger_wing_flap)

func _prepare_bird_entrance() -> void:
	if not burung_sprite:
		return
	burung_sprite.set_meta("target_pos", burung_sprite.position)
	burung_sprite.set_meta("target_scale", burung_sprite.scale)
	burung_sprite.position += bird_enter_offset
	burung_sprite.scale *= bird_start_scale_multiplier

func _play_bird_entrance() -> void:
	if not burung_sprite:
		return
	var target_pos: Vector2 = burung_sprite.get_meta("target_pos", burung_sprite.position)
	var target_scale: Vector2 = burung_sprite.get_meta("target_scale", burung_sprite.scale)

	var t := create_tween().set_parallel(true)
	t.tween_property(burung_sprite, "position", target_pos, bird_enter_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(burung_sprite, "scale", target_scale, bird_enter_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var hover_tween := create_tween().set_loops()
	hover_tween.tween_property(burung_sprite, "position:y", -5.0, 1.4).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_tween.tween_property(burung_sprite, "position:y", 5.0, 1.4).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _prepare_diagonal_pan() -> void:
	if landscape_1:
		landscape_1.set_meta("start_offset", landscape_1.scroll_offset)
	if landscape_2:
		landscape_2.set_meta("start_offset", landscape_2.scroll_offset)

func _play_diagonal_pan() -> void:
	if landscape_1:
		var start_1: Vector2 = landscape_1.get_meta("start_offset", landscape_1.scroll_offset)
		var pan_1 := create_tween()
		pan_1.tween_property(landscape_1, "scroll_offset", start_1 + pan_offset, pan_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if landscape_2:
		var start_2: Vector2 = landscape_2.get_meta("start_offset", landscape_2.scroll_offset)
		var pan_2 := create_tween()
		pan_2.tween_property(landscape_2, "scroll_offset", start_2 + pan_offset, pan_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _fade_in_landscape_2() -> void:
	if not landscape_2:
		return
	bg2_fade_tween = create_tween()
	bg2_fade_tween.tween_property(landscape_2, "modulate:a", 1.0, bg_2_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _transition_to_landscape_3() -> void:
	if not landscape_3:
		return

	# Awan (Landscape 2) dipudarkan perlahan
	if landscape_2:
		var fade_cloud := create_tween()
		fade_cloud.tween_property(landscape_2, "modulate:a", 0.0, bg_3_reveal_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Atur geseran gambar Landscape 3
	var start_offset_3: Vector2 = landscape_3.scroll_offset
	var target_offset_3: Vector2 = start_offset_3 + Vector2(550.0, 300.0)

	# Jalankan tween parallel HANYA untuk landscape (burung tetap diam di posisinya)
	var t := create_tween().set_parallel(true)
	# Munculkan Landscape 3
	t.tween_property(landscape_3, "modulate:a", 1.0, bg_3_reveal_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Geser gambar Landscape-nya saja
	t.tween_property(landscape_3, "scroll_offset", target_offset_3, bg_3_pan_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Mulai fade-in BGM di 65% perjalanan pan (pas sebelum ease-out melambat di ujung)
	t.tween_callback(_play_vietnam_bgm).set_delay(bg_3_pan_duration * 0.65)

	# Putar BGM Vietnam TEPAT saat pergeseran Landscape 3 selesai (enggang sampai di ujung)
	t.finished.connect(_play_vietnam_bgm)

func _play_vietnam_bgm() -> void:
	if not is_inside_tree():
		return
	if MusicManager and MusicManager.has_method("play_world_audio"):
		MusicManager.play_world_audio(null, VIETNAM_BGM, -8.0, -12.0)

func _start_vietnam_bgm_now() -> void:
	if not is_inside_tree():
		return
	if MusicManager and MusicManager.has_method("play_world_audio"):
		MusicManager.play_world_audio(null, VIETNAM_BGM, -8.0, -12.0)

func _play_initial_black_screen() -> void:
	if SceneTransition and SceneTransition.has_method("fade_in"):
		SceneTransition.fade_in()

	var overlay := CanvasLayer.new()
	overlay.layer = 15
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(rect)
	add_child(overlay)

	await get_tree().create_timer(initial_black_delay).timeout

	var fade_t := create_tween()
	fade_t.tween_property(rect, "modulate:a", 0.0, 1.5)
	await fade_t.finished
	overlay.queue_free()

func _play_cutscene_dialogue() -> void:
	if not DialogueManager or not DialogueManager.has_method("start_dialogue"):
		push_warning("DialogueManager tidak ditemukan!")
		return

	if "is_active" in DialogueManager:
		DialogueManager.is_active = false

	for entry in cutscene_dialogues:
		if entry.get("trigger_bg2", false):
			_fade_in_landscape_2()
		if entry.get("trigger_bg3", false):
			_transition_to_landscape_3()

		var speaker_name: String = entry.get("speaker", "Enggang")
		var target_pivot: Node2D = pivot_danum if speaker_name == "Danum" else pivot_enggang
		if not is_instance_valid(target_pivot):
			target_pivot = self

		var line_array: Array[String] = [entry["text"]]
		DialogueManager.start_dialogue(line_array, target_pivot)

		await get_tree().process_frame
		if "is_active" in DialogueManager:
			while DialogueManager.is_active:
				await get_tree().process_frame
		elif DialogueManager.has_signal("dialogue_finished"):
			await DialogueManager.dialogue_finished
		elif DialogueManager.has_signal("dialogue_ended"):
			await DialogueManager.dialogue_ended
