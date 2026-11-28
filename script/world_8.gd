extends Node2D

@export_group("Cutscene World 8 Settings")
@export var zoom_out_scale: Vector2 = Vector2(0.72, 0.72) # Skala zoom out luas di awal cutscene
@export var zoom_in_danum_scale: Vector2 = Vector2(2.05, 2.05) # Skala zoom full-body ke Danum
@export var danum_closeup_offset: Vector2 = Vector2(0.0, 68.0) # Y positif besar agar kamera turun ke bawah (badan penuh Danum terlihat)
@export var closeup_dialogue_pivot_offset_y: float = 18.0 # Menurunkan posisi DialoguePivot Danum saat zoom in agar bubble tidak kepotong atas
@export var zoom_out_duration: float = 1.8 # Durasi animasi kamera zoom out awal
@export var zoom_in_duration: float = 0.75 # Durasi zoom in ke Danum
@export var zoom_out_return_duration: float = 1.9 # Durasi kembali ke kamera ukuran biasa secara lambat
@export var zoom_out_offset_y: float = 45.0 # Seberapa jauh kamera naik ke atas saat zoom out luas di awal
@export var center_offset_adjustment: float = 45.0 # Geser kamera agak ke kanan saat zoom out
@export var vanish_feather_delay: float = 0.45 # Delay kemunculan bulu rontok agar terlihat melayang pas proses zoom out
@export var intro_fade_in_duration: float = 1.0 # Durasi layar hitam membuka ke world_8
@export var pre_dialogue_pause: float = 0.8 # Jeda sejenak setelah zoom out selesai sebelum dialog dimulai
@export var wing_flap_sfx: AudioStream # Drag audio sayap Enggang ke sini

@onready var player: CharacterBody2D = $Player
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var npc_enggang: Node2D = $NPC_Enggang
@onready var enggang_dialogue_pivot: Marker2D = $NPC_Enggang/DialoguePivot

var has_played_cutscene: bool = false
var base_cam_zoom: Vector2 = Vector2.ONE
var base_cam_offset: Vector2 = Vector2.ZERO
var midpoint_offset_x: float = 0.0


func _ready() -> void:
	# Posisikan Player di SpawnPoint jika ada
	if spawn_point and player:
		player.global_position = spawn_point.global_position

	# Pastikan Danum menghadap ke kiri (ke arah NPC_Enggang) di awal
	var player_anim := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if player_anim:
		player_anim.flip_h = true

	if not has_played_cutscene:
		has_played_cutscene = true
		call_deferred("_start_world_8_cutscene")


func _start_world_8_cutscene() -> void:
	if not is_instance_valid(player):
		return

	# 1. Kunci kontrol pemain sejak awal
	if player.has_method("disable_movement"):
		player.disable_movement()
	elif "can_move" in player:
		player.can_move = false
	player.velocity = Vector2.ZERO

	# 2. Ambil layar hitam persisten dari world_7 (atau buat baru jika test langsung di world_8)
	var intro_layer: CanvasLayer = null
	var intro_black: ColorRect = null

	if get_tree().root.has_meta("world7_to_world8_fade"):
		intro_layer = get_tree().root.get_meta("world7_to_world8_fade") as CanvasLayer
		get_tree().root.remove_meta("world7_to_world8_fade")
		if is_instance_valid(intro_layer) and intro_layer.get_child_count() > 0:
			intro_black = intro_layer.get_child(0) as ColorRect

	if not is_instance_valid(intro_layer) or not is_instance_valid(intro_black):
		intro_layer = CanvasLayer.new()
		intro_layer.layer = 100
		add_child(intro_layer)

		intro_black = ColorRect.new()
		intro_black.color = Color(0, 0, 0, 1.0)
		intro_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		intro_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		intro_layer.add_child(intro_black)

	# 3. Fade in layar dari hitam ke terang
	var fade_in := create_tween()
	fade_in.tween_property(intro_black, "color:a", 0.0, intro_fade_in_duration)
	await fade_in.finished
	intro_layer.queue_free()

	# 4. Simpan kamera ukuran biasa & jalankan animasi Zoom Out awal (agak ke kanan)
	var player_cam := _find_camera(player)
	if is_instance_valid(player_cam):
		base_cam_zoom = player_cam.zoom
		base_cam_offset = player_cam.offset

		var wide_cam_zoom: Vector2 = base_cam_zoom * zoom_out_scale
		midpoint_offset_x = base_cam_offset.x + center_offset_adjustment
		var target_offset_y: float = base_cam_offset.y - zoom_out_offset_y

		if is_instance_valid(npc_enggang):
			var midpoint_x: float = (player.global_position.x + npc_enggang.global_position.x) * 0.5
			midpoint_offset_x = (midpoint_x - player.global_position.x) + center_offset_adjustment

		var wide_cam_offset := Vector2(midpoint_offset_x, target_offset_y)

		var cam_tween := create_tween().set_parallel(true)
		cam_tween.tween_property(player_cam, "zoom", wide_cam_zoom, zoom_out_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(player_cam, "offset", wide_cam_offset, zoom_out_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await cam_tween.finished

	await get_tree().create_timer(pre_dialogue_pause).timeout

	# 5. Jalankan dialog & transisi zoom ke Danum lalu kembali ke kamera ukuran biasa
	await _play_world_8_dialogue(player_cam)

	# 6. Buka kembali kontrol pemain setelah seluruh adegan selesai
	if is_instance_valid(player):
		if player.has_method("enable_movement"):
			player.enable_movement()
		elif "can_move" in player:
			player.can_move = true


func _play_world_8_dialogue(player_cam: Camera2D) -> void:
	var p := _get_player_pivot()
	var e: Node2D = enggang_dialogue_pivot if is_instance_valid(enggang_dialogue_pivot) else npc_enggang
	var player_anim := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	await _say(["Hutan ini... masih terlihat begitu menyedihkan."], p)
	await _say(["Perjalananmu baru saja dimulai, Danum.", "Apa yang akan kamu lakukan sekarang?"], e)
	await _say([
		"Aku akan mengajak masyarakat desaku untuk membangun kembali hutan ini.",
		"Kita bisa membuat tempat wisata yang dikelola bersama, serta mengenalkan budaya dan kehidupan masyarakat kepada pengunjung.",
		"Kita juga akan menanam kembali pohon-pohon yang telah hilang."
	], p)
	await _say(["Baiklah, Danum aku yakin kamu bisa melakukannya!"], e)

	# Zoom in full-body ke Danum (Enggang di luar layar)
	if is_instance_valid(player_cam):
		var closeup_zoom: Vector2 = base_cam_zoom * zoom_in_danum_scale
		var closeup_offset: Vector2 = base_cam_offset + danum_closeup_offset
		var zoom_in_tween := create_tween().set_parallel(true)
		zoom_in_tween.tween_property(player_cam, "zoom", closeup_zoom, zoom_in_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		zoom_in_tween.tween_property(player_cam, "offset", closeup_offset, zoom_in_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await zoom_in_tween.finished

	# Turunkan posisi DialoguePivot Danum sementara agar bubble dialog pas di layar saat zoom in
	var orig_pivot_pos: Vector2 = p.position
	if p != player:
		p.position.y += closeup_dialogue_pivot_offset_y

	await _say(["Ayo kita mulai Enggang!"], p)

	# Kembalikan posisi DialoguePivot Danum ke semula
	if p != player:
		p.position = orig_pivot_pos

	# Danum berbalik badan ke kanan (membelakangi arah Enggang)
	if is_instance_valid(player_anim):
		player_anim.flip_h = false

	await get_tree().create_timer(0.35).timeout

	# Enggang menghilang di luar bingkai kamera, sementara bulu rontok diberi delay agar terlihat jatuh pas zoom out
	if is_instance_valid(npc_enggang):
		_play_sfx(wing_flap_sfx)
		var vanish_pos: Vector2 = npc_enggang.global_position
		npc_enggang.visible = false
		_spawn_vanish_feathers_delayed(vanish_pos, vanish_feather_delay)

	await get_tree().create_timer(0.55).timeout

	# Danum berbalik kembali ke kiri
	if is_instance_valid(player_anim):
		player_anim.flip_h = true

	await get_tree().create_timer(0.25).timeout

	# Kamera kembali ke UKURAN BIASA (agak ke kanan) secara lambat sambil melihat bulu terakhir jatuh
	if is_instance_valid(player_cam):
		var normal_return_offset := Vector2(midpoint_offset_x, base_cam_offset.y)
		var zoom_back_tween := create_tween().set_parallel(true)
		zoom_back_tween.tween_property(player_cam, "zoom", base_cam_zoom, zoom_out_return_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		zoom_back_tween.tween_property(player_cam, "offset", normal_return_offset, zoom_out_return_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await zoom_back_tween.finished

	await get_tree().create_timer(0.25).timeout
	await _say(["Ehh… Enggang?"], p)

	# Jeda sejenak setelah Danum sadar Enggang pergi, lalu fade ke hitam
	await get_tree().create_timer(0.6).timeout

	var out_layer := CanvasLayer.new()
	out_layer.layer = 100
	get_tree().root.add_child(out_layer)
	get_tree().root.set_meta("world8_to_outro_fade", out_layer)

	var out_black := ColorRect.new()
	out_black.color = Color(0, 0, 0, 0.0)
	out_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	out_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_layer.add_child(out_black)

	var fade_out := create_tween()
	fade_out.tween_property(out_black, "color:a", 1.0, 1.2)
	await fade_out.finished

	# Pindah ke scene outro_narrative.tscn
	# Pindah ke scene outro_narrative.tscn
	get_tree().change_scene_to_file("res://scene/Function/outro_narrative.tscn")


func _spawn_vanish_feathers_delayed(spawn_pos: Vector2, delay_sec: float) -> void:
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
	if not is_inside_tree():
		return

	var feather_texture := preload("res://assets/animation/Bulu.png")
	for i in range(12):
		var feather := Sprite2D.new()
		feather.texture = feather_texture
		feather.z_index = 15
		feather.global_position = spawn_pos + Vector2(randf_range(-20.0, 75.0), randf_range(-85.0, -15.0))
		var s := randf_range(0.55, 0.95)
		feather.scale = Vector2(s, s)
		feather.flip_h = randf() > 0.5
		add_child(feather)

		var dur := randf_range(1.8, 2.7)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(feather, "global_position:y", feather.global_position.y + randf_range(95.0, 155.0), dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(feather, "global_position:x", feather.global_position.x + randf_range(-25.0, 25.0), dur)
		tw.tween_property(feather, "rotation", randf_range(-2.5, 2.5), dur)
		tw.tween_property(feather, "modulate:a", 0.0, dur).set_delay(dur * 0.55)
		tw.chain().tween_callback(feather.queue_free)


func _find_camera(target_player: Node2D) -> Camera2D:
	if is_instance_valid(target_player):
		var cam := target_player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			return cam
	return get_viewport().get_camera_2d()


func _play_sfx(stream: AudioStream) -> void:
	if not stream:
		return
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = stream
	sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)


func _say(lines: Array[String], pivot: Node2D) -> void:
	if not DialogueManager:
		return

	DialogueManager.start_dialogue(lines, pivot)
	if "is_active" in DialogueManager:
		while DialogueManager.is_active:
			await get_tree().process_frame
	elif DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	elif DialogueManager.has_signal("dialogue_ended"):
		await DialogueManager.dialogue_ended


func _get_player_pivot() -> Node2D:
	if is_instance_valid(player):
		var custom_pivot := player.get_node_or_null("DialoguePivot") as Node2D
		if custom_pivot:
			return custom_pivot
		return player
	return self
