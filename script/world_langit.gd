extends Node2D

@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)
@onready var landscape_sprite: Sprite2D = $LandscapeParallax/Sprite2D
@onready var landscape_sprite_2: Sprite2D = $LandscapeParallax2/Sprite2D
@onready var landscape_sprite_3: Sprite2D = $LandscapeParallax3/Sprite2D
@onready var burung_sprite: Sprite2D = $BurungSprite
@onready var burung_sprite_2: Sprite2D = $BurungSprite/BurungSprite2
@onready var wing_flap_sfx: AudioStreamPlayer = get_node_or_null("WingFlapSFX")

# Dua pivot terpisah yang menjadi anak dari BurungSprite
@onready var pivot_danum: Marker2D = $BurungSprite/PivotDanum
@onready var pivot_enggang: Marker2D = $BurungSprite/PivotEnggang

# --- PENGATURAN SFX KEPAKAN SAYAP ---
@export var wing_flap_interval: float = 12.0
@export var wing_pitch_min: float = 0.50
@export var wing_pitch_max: float = 0.90

# --- PENGATURAN GERAKAN BACKGROUND 1 (KIRI ATAS -> KANAN BAWAH) ---
@export var pan_offset: Vector2 = Vector2(430.0, 240.0)
@export var pan_duration: float = 35.0
@export var bg2_fade_duration: float = 3.5

# --- PENGATURAN TRANSISI AWAN -> LANDSCAPE 3 (VIETNAM) ---
@export var cloud_hold_duration: float = 5.0
@export var bg3_reveal_duration: float = 2.0
@export var bg3_pan_duration: float = 6.0

# --- PENGATURAN ENGGANG MASUK HINGGA PAS DI TENGAH KAMERA (SCALE 1.0) ---
@export var bird_enter_offset: Vector2 = Vector2(45.0, 35.0)
@export var bird_start_scale_multiplier: float = 1.25
@export var bird_enter_duration: float = 10.0

@onready var fire_ambience_sfx: AudioStreamPlayer = get_node_or_null("FireAmbienceSFX")
@export var initial_black_delay: float = 3.0

@export var wind_sfx_stream: AudioStream # Masukkan file audio angin di Inspector jika pakai node baru/existing
@export var wind_sfx_db: float = -6.0
@onready var wind_sfx: AudioStreamPlayer = $WindSFX if has_node("WindSFX") else null
@export var bg3_audio_stream: AudioStream # Masukkan file audio landscape 3 di Inspector
@export var bg3_audio_db: float = -6.0
var bg3_audio_player: AudioStreamPlayer
@export var bg3_audio_fade_out_duration: float = 1.2

var bg2_fade_tween: Tween
var is_flapping: bool = false

# --- NASKAH DIALOG CUTSCENE DENGAN PENANDA PEMBICARA ---
var cutscene_dialogues: Array[Dictionary] = [
	{"speaker": "danum", "text": "H-hah!? Di mana aku?"},
	{"speaker": "enggang", "text": "Danum, akhirnya kamu sadar."},
	{"speaker": "danum", "text": "Huaaa, s-siapa kamu?"},
	{"speaker": "enggang", "text": "Tenanglah, namaku Enggang. Aku adalah roh penjaga hutan ini."},
	{"speaker": "danum", "text": "Lalu kenapa kamu menyelamatkanku?"},
	{"speaker": "enggang", "text": "Karena aku melihat keberanianmu menjaga hutan dari dua perusak tadi."},
	{"speaker": "enggang", "text": "Tapi lihatlah ke bawah, Danum... hutan yang kamu lindungi telah dilahap api."},
	{"speaker": "danum", "text": "Tidaaak... hutan ini... Kok bisa sampai seperti ini?"},
	{"speaker": "enggang", "text": "Ini hanyalah permulaan jika manusia terus merusak alam tanpa memikirkan akibatnya."},
	{"speaker": "enggang", "text": "Karena itu aku memilihmu menjadi penjaga hutan ini."},
	{"speaker": "danum", "text": "HAH? Kenapa harus aku? Aku kan cuma anak kecil."},
	{"speaker": "enggang", "text": "Menjaga hutan bukan hanya soal kekuatan, tapi seberapa jauh kamu menghargai kehidupan di dalamnya."},
	{"speaker": "enggang", "text": "Di dunia lain, ada masyarakat yang memiliki kearifan untuk hidup berdampingan dengan alam."},
	{"speaker": "enggang", "text": "Di sana kamu bisa menemukan cara untuk menyelamatkan hutan kita."},
	{"speaker": "danum", "text": "Dunia lain? Di mana itu?"},
	{"speaker": "enggang", "text": "Berpeganglah, Danum! Petualangan kita dimulai sekarang."}
]

func _ready() -> void:
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()
		
	if landscape_sprite_2:
		landscape_sprite_2.modulate.a = 0.0
	if landscape_sprite_3:
		landscape_sprite_3.modulate.a = 0.0
	if burung_sprite_2:
		burung_sprite_2.modulate.a = 0.0
		
	# Buat tirai hitam penuh di atas layar sejak frame pertama
	var black_layer := CanvasLayer.new()
	black_layer.layer = 100
	var black_rect := ColorRect.new()
	black_rect.color = Color.BLACK
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_layer.add_child(black_rect)
	add_child(black_layer)
		
	# 1. Siapkan posisi awal & nyalakan audio saat layar masih hitam pekat
	var bg1_end_pos := _prepare_diagonal_pan(landscape_sprite)
	var bird_end_pos := _prepare_bird_entrance()
	
	_start_wing_flap_loop()
	if fire_ambience_sfx and not fire_ambience_sfx.playing:
		fire_ambience_sfx.play()
		
	# 2. Tahan layar hitam pekat selama 3 detik (initial_black_delay)
	if initial_black_delay > 0.0:
		await get_tree().create_timer(initial_black_delay, true).timeout
	
	# 3. Jalankan animasi gerak bersamaan dengan terbukanya layar hitam (baik tirai lokal maupun SceneTransition)
	_play_diagonal_pan(landscape_sprite, bg1_end_pos, pan_duration)
	_play_bird_entrance(bird_end_pos, bird_enter_duration)
	
	var fade_in_tween := create_tween()
	fade_in_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in_tween.tween_property(black_rect, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()
		
	if fade_in_tween.is_running():
		await fade_in_tween.finished
	black_layer.queue_free()
		
	# 4. Jalankan rangkaian dialog
	await get_tree().create_timer(0.5, true).timeout
	await _play_cutscene_dialogues()
	# Fade-out audio BG3 dan suara angin secara paralel sebelum pindah ke world_2
	var has_bg3_playing: bool = is_instance_valid(bg3_audio_player) and bg3_audio_player.playing
	var has_wind_playing: bool = is_instance_valid(wind_sfx) and wind_sfx.playing

	if has_bg3_playing or has_wind_playing:
		var audio_out := create_tween().set_parallel(true)
		audio_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		if has_bg3_playing:
			audio_out.tween_property(bg3_audio_player, "volume_db", -40.0, bg3_audio_fade_out_duration)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if has_wind_playing:
			audio_out.tween_property(wind_sfx, "volume_db", -40.0, bg3_audio_fade_out_duration)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		await audio_out.finished

		if has_bg3_playing:
			bg3_audio_player.stop()
		if has_wind_playing:
			wind_sfx.stop()

func _start_wing_flap_loop() -> void:
	if not wing_flap_sfx:
		return
		
	is_flapping = true
	while is_flapping and is_inside_tree():
		wing_flap_sfx.pitch_scale = randf_range(wing_pitch_min, wing_pitch_max)
		wing_flap_sfx.play()
		# Parameter true pertama membuat timer tetap berjalan meski DialogueManager mem-pause game
		await get_tree().create_timer(wing_flap_interval, true).timeout

func _prepare_bird_entrance() -> Vector2:
	if not burung_sprite:
		return Vector2.ZERO
		
	var bird_end_pos: Vector2 = camera_2d.global_position if camera_2d else Vector2.ZERO
	var bird_end_scale: Vector2 = Vector2.ONE
	
	burung_sprite.global_position = bird_end_pos + bird_enter_offset
	burung_sprite.scale = bird_end_scale * bird_start_scale_multiplier
	return bird_end_pos

func _play_bird_entrance(bird_end_pos: Vector2, duration: float) -> void:
	if not burung_sprite:
		return
		
	var bird_tween := create_tween().set_parallel(true)
	bird_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	bird_tween.tween_property(burung_sprite, "global_position", bird_end_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bird_tween.tween_property(burung_sprite, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _prepare_diagonal_pan(target_sprite: Sprite2D) -> Vector2:
	if not target_sprite or not target_sprite.texture:
		return Vector2.ZERO
		
	var tex_size: Vector2 = target_sprite.texture.get_size()
	var view_size: Vector2 = get_viewport_rect().size / (camera_2d.zoom if camera_2d else Vector2.ONE)
	var cam_center: Vector2 = camera_2d.global_position if camera_2d else Vector2.ZERO
	
	var needed_size: Vector2 = view_size + pan_offset
	var min_scale: float = max(needed_size.x / tex_size.x, needed_size.y / tex_size.y)
	if target_sprite.scale.x < min_scale:
		target_sprite.scale = Vector2(min_scale, min_scale)
		
	var scaled_half: Vector2 = (tex_size * target_sprite.scale) * 0.5
	var view_half: Vector2 = view_size * 0.5
	
	var cam_top_left: Vector2 = cam_center - view_half
	var end_pos: Vector2 = cam_top_left + scaled_half
	target_sprite.global_position = end_pos - pan_offset
	return end_pos

func _play_diagonal_pan(target_sprite: Sprite2D, end_pos: Vector2, duration: float) -> void:
	if not target_sprite:
		return
		
	var pan_tween := create_tween()
	pan_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pan_tween.tween_property(target_sprite, "global_position", end_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fade_in_landscape_2() -> void:
	if not landscape_sprite_2 or not landscape_sprite_2.texture:
		return

	# Pudarkan suara kebakaran hingga hilang seiring masuknya awan (Landscape 2)
	if fire_ambience_sfx and fire_ambience_sfx.playing:
		var fire_fade_tween := create_tween()
		fire_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fire_fade_tween.tween_property(fire_ambience_sfx, "volume_db", -40.0, bg2_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fire_fade_tween.tween_callback(fire_ambience_sfx.stop)

	var tex_size: Vector2 = landscape_sprite_2.texture.get_size()
	var view_size: Vector2 = get_viewport_rect().size / (camera_2d.zoom if camera_2d else Vector2.ONE)
	var cam_center: Vector2 = camera_2d.global_position if camera_2d else Vector2.ZERO

	var scaled_half: Vector2 = (tex_size * landscape_sprite_2.scale) * 0.5
	var view_half: Vector2 = view_size * 0.5
	var cam_top_left: Vector2 = cam_center - view_half
	var bg2_end_pos: Vector2 = cam_top_left + scaled_half

	var pan_tween := create_tween()
	pan_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pan_tween.tween_property(landscape_sprite_2, "global_position", bg2_end_pos, 15.0).set_trans(Tween.TRANS_LINEAR)

	bg2_fade_tween = create_tween()
	bg2_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	bg2_fade_tween.tween_property(landscape_sprite_2, "modulate:a", 1.0, bg2_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Nyalakan SFX angin saat masuk ke awan (landscape_2)
	if wind_sfx_stream:
		if not wind_sfx:
			wind_sfx = AudioStreamPlayer.new()
			wind_sfx.name = "WindSFX"
			add_child(wind_sfx)
		wind_sfx.stream = wind_sfx_stream
		wind_sfx.volume_db = -35.0
		wind_sfx.play()
		var wind_in_tween := create_tween()
		wind_in_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		wind_in_tween.tween_property(wind_sfx, "volume_db", wind_sfx_db, bg2_fade_duration)\
			.set_trans(Tween.TRANS_SINE)

func _transition_to_landscape_3() -> void:
	# Nyalakan audio khusus Landscape 3 dengan fade-in halus (suara angin tetap berjalan)
	if bg3_audio_stream:
		if not bg3_audio_player:
			bg3_audio_player = AudioStreamPlayer.new()
			bg3_audio_player.name = "Bg3AudioSFX"
			add_child(bg3_audio_player)
		bg3_audio_player.stream = bg3_audio_stream
		bg3_audio_player.volume_db = -35.0
		bg3_audio_player.play()
		var bg3_audio_in := create_tween()
		bg3_audio_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		bg3_audio_in.tween_property(bg3_audio_player, "volume_db", bg3_audio_db, bg3_reveal_duration)\
			.set_trans(Tween.TRANS_SINE)

	var bg3_pos_tween: Tween
	# ... (lanjutkan sisa kode posisi & reveal Landscape 3 di bawahnya)

	if landscape_sprite_3 and landscape_sprite_3.texture:
		var tex_size: Vector2 = landscape_sprite_3.texture.get_size()
		var view_size: Vector2 = get_viewport_rect().size / (camera_2d.zoom if camera_2d else Vector2.ONE)
		var cam_center: Vector2 = camera_2d.global_position if camera_2d else Vector2.ZERO

		if landscape_sprite_3.scale.x < 1.3:
			landscape_sprite_3.scale = Vector2(1.3, 1.3)

		var final_scale: Vector2 = landscape_sprite_3.scale
		var scalar_half: Vector2 = (tex_size * final_scale) * 0.5
		var view_half: Vector2 = view_size * 0.5

		var cam_bottom_right: Vector2 = cam_center + view_half
		var start_pos: Vector2 = cam_bottom_right - scalar_half

		var cam_top_left: Vector2 = cam_center - view_half
		var end_pos: Vector2 = cam_top_left + scalar_half

		# Mulai dari transparan & skala lebih kecil sebelum membesar ke ukuran target
		landscape_sprite_3.modulate.a = 0.0
		landscape_sprite_3.scale = final_scale * 0.85
		landscape_sprite_3.global_position = start_pos

		bg3_pos_tween = create_tween()
		bg3_pos_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		bg3_pos_tween.tween_property(landscape_sprite_3, "global_position", end_pos, bg3_pan_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var reveal_tween := create_tween().set_parallel(true)
	reveal_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if landscape_sprite_3 and landscape_sprite_3.texture:
		var target_scale: Vector2 = Vector2(1.3, 1.3) if landscape_sprite_3.scale.x / 0.85 < 1.3 else landscape_sprite_3.scale / 0.85
		reveal_tween.tween_property(landscape_sprite_3, "modulate:a", 1.0, bg3_reveal_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(landscape_sprite_3, "scale", target_scale, bg3_reveal_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if landscape_sprite_2:
		reveal_tween.tween_property(landscape_sprite_2, "modulate:a", 0.0, bg3_reveal_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if burung_sprite_2:
		reveal_tween.tween_property(burung_sprite_2, "modulate:a", 1.0, bg3_reveal_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await reveal_tween.finished

	if bg3_pos_tween and bg3_pos_tween.is_running():
		await bg3_pos_tween.finished

func _play_cutscene_dialogues() -> void:
	for entry in cutscene_dialogues:
		if entry["text"] == "Berpeganglah, Danum! Petualangan kita dimulai sekarang.":
			_fade_in_landscape_2()
			
		var target_pivot: Marker2D = pivot_danum if entry["speaker"] == "danum" else pivot_enggang
		var line_array: Array[String] = [entry["text"]]
		
		DialogueManager.start_dialogue(line_array, target_pivot)
		
		while DialogueManager.is_active:
			await get_tree().process_frame
			
	if bg2_fade_tween and bg2_fade_tween.is_running():
		await bg2_fade_tween.finished
		
	await get_tree().create_timer(cloud_hold_duration).timeout
	await _transition_to_landscape_3()
	await get_tree().create_timer(1.5).timeout
	# Hentikan loop dan pudarkan volume kepakan sayap sebelum pindah scene
	is_flapping = false
	if wing_flap_sfx and wing_flap_sfx.playing:
		var sfx_tween := create_tween()
		sfx_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		sfx_tween.tween_property(wing_flap_sfx, "volume_db", -40.0, 0.8)
		await sfx_tween.finished
		wing_flap_sfx.stop()
		
	# Pastikan tree tidak dalam keadaan paused sebelum pindah scene
	get_tree().paused = false
	
	var next_scene_path := "res://scene/World/world_2.tscn"
	if not ResourceLoader.exists(next_scene_path):
		push_error("File scene tidak ditemukan: " + next_scene_path)
		return
		
	if SceneTransition and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(next_scene_path)
	else:
		get_tree().change_scene_to_file(next_scene_path)
	# Hentikan loop dan pudarkan volume kepakan sayap sebelum
