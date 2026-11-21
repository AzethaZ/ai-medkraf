extends Node2D

@export var camera_limit_left: int = -1440
@export var camera_limit_right: int = -230

@export var intro_black_duration: float = 2.0
@export var intro_fade_duration: float = 1.5

const VIETNAM_BGM = preload("res://assets/audio/viatnamese_bgm.mp3")

@onready var player: Node2D = $Player
@onready var wing_flap_sfx: AudioStreamPlayer = get_node_or_null("WingFlapSFX")

func _ready() -> void:
	# 1. Putar BGM Vietnam
	if MusicManager and MusicManager.has_method("play_world_audio"):
		MusicManager.play_world_audio(null, VIETNAM_BGM, -5.0, -12.0)

	# 2. Cek apakah ini pertama kali masuk world_4
	var sudah_masuk_world4: bool = false
	if GameState and GameState.has_meta("world_4_entry_played"):
		sudah_masuk_world4 = GameState.get_meta("world_4_entry_played")

	# Pindahkan Player ke Spawn1 jika pertama kali masuk, atau ke target_spawn_id / SpawnPoint jika sudah pernah
	var spawn_name: String = "SpawnPoint"
	if SceneTransition and "target_spawn_id" in SceneTransition and SceneTransition.target_spawn_id != "":
		spawn_name = SceneTransition.target_spawn_id
		SceneTransition.target_spawn_id = ""
	elif not sudah_masuk_world4:
		spawn_name = "Spawn1"

	_move_player_to_spawn(spawn_name)

	# 3. Atur batas kamera world_4
	var cam: Camera2D = _find_camera(self)
	if cam:
		cam.enabled = true
		cam.make_current()
		cam.limit_left = camera_limit_left
		cam.limit_right = camera_limit_right

	# 4. Jalankan efek mendarat (tirai hitam + kepakan sayap 1x + hujan bulu) HANYA SEKALI
	if not sudah_masuk_world4:
		if GameState:
			GameState.set_meta("world_4_entry_played", true)

		if player and player.has_method("disable_movement"):
			player.disable_movement()

		await _play_world_entry_transition()

		if player and player.has_method("enable_movement"):
			player.enable_movement()
	else:
		if SceneTransition and SceneTransition.has_method("fade_in"):
			await SceneTransition.fade_in()

func _play_world_entry_transition() -> void:
	# 1. Tutup layar penuh dengan tirai hitam sejak frame pertama
	var black_layer := CanvasLayer.new()
	black_layer.layer = 100
	var black_rect := ColorRect.new()
	black_rect.color = Color.BLACK
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_layer.add_child(black_rect)
	add_child(black_layer)

	# 2. Putar suara kepakan sayap 1 kali selama layar hitam
	_trigger_wing_flap()
	await get_tree().create_timer(intro_black_duration, true).timeout

	# 3. Buka tirai hitam + munculkan hujan bulu di sekitar posisi Danum (Spawn1)
	var fade_tween := create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_property(black_rect, "modulate:a", 0.0, intro_fade_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	if SceneTransition and SceneTransition.has_method("fade_in"):
		SceneTransition.fade_in()

	var feather_origin: Vector2 = player.global_position if player else Vector2.ZERO
	spawn_feather_shower(feather_origin)

	await fade_tween.finished
	black_layer.queue_free()

func _trigger_wing_flap() -> void:
	if wing_flap_sfx and wing_flap_sfx.stream:
		wing_flap_sfx.pitch_scale = randf_range(0.95, 1.05)
		wing_flap_sfx.play()
	else:
		play_flying_sound()

func play_flying_sound() -> void:
	var fly_sfx = preload("res://assets/audio/wing_sound.mp3")
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = fly_sfx
	sfx_player.volume_db = -10.0
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

func spawn_feather_shower(spawn_pos: Vector2) -> void:
	var feather_texture = preload("res://assets/animation/Bulu.png")

	for i in range(15):
		var feather = Sprite2D.new()
		feather.texture = feather_texture
		feather.z_index = 10

		var offset_x = randf_range(-130, 20)
		var offset_y = randf_range(-130, 50)
		feather.global_position = spawn_pos + Vector2(offset_x, offset_y)

		var random_scale = randf_range(0.5, 1.0)
		feather.scale = Vector2(random_scale, random_scale)

		feather.flip_h = randf() > 0.5
		feather.flip_v = randf() > 0.5
		add_child(feather)

		var fall_duration = randf_range(1.5, 2.5)

		var target_x = feather.global_position.x + randf_range(-60, 10)
		var target_y = feather.global_position.y + randf_range(140, 220)

		var tween = create_tween().set_parallel(true)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(feather, "global_position:y", target_y, fall_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(feather, "global_position:x", target_x, fall_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(feather, "rotation", randf_range(-3.0, 3.0), fall_duration)
		tween.tween_property(feather, "modulate:a", 0.0, fall_duration)\
			.set_delay(fall_duration * 0.5)

		tween.chain().tween_callback(feather.queue_free)

func _move_player_to_spawn(spawn_name: String) -> void:
	var spawn_node = find_child(spawn_name, true, false)
	if spawn_node and player:
		player.global_position = spawn_node.global_position

func _find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found:
			return found
	return null
