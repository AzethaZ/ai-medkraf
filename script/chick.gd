extends CharacterBody2D

# ID Unik Anak Ayam (Set di Inspector Godot untuk tiap ayam)
@export var chick_id: String = "chick_1"

@export var follow_speed: float = 120.0
@export var wander_speed: float = 45.0 # Kecepatan jalan santai saat jauh
@export var follow_delay: float = 0.22 # Jeda waktu (detik) anak ayam meniru gerak & lompatan MC

var target_node: Node2D = null
var is_following: bool = false
var offset_x: float = 0.0

# State Pergerakan ketika Idle/Sama
enum State { FOLLOWING_PLAYER, IDLE_WAIT, IDLE_WANDER }
var current_state: State = State.IDLE_WAIT

var idle_timer: float = 0.0
var wander_target_x: float = 0.0
var last_player_x: float = 0.0

# Riwayat posisi MC untuk efek delay & koordinat tanah bayangan
var position_history: Array[Dictionary] = []
var ground_y: float = 0.0
var shadow_offset_y: float = 0.0

# Referensi Node
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Sprite2D = get_node_or_null("Shadow")
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer if has_node("AudioStreamPlayer") else null

# Timer Suara Anak Ayam
var chirp_timer: float = 0.0
@export var min_chirp_interval: float = 3.0
@export var max_chirp_interval: float = 7.0
var next_chirp_time: float = 4.0


func _ready() -> void:
	# Cek apakah ayam ini sudah pernah diambil & disimpan
	if GameManager and GameManager.has_method("is_chick_collected"):
		if GameManager.is_chick_collected(chick_id):
			queue_free()
			return

	ground_y = global_position.y
	if shadow:
		shadow_offset_y = shadow.position.y

	# Acak frame awal & kecepatan animasi tiap anak ayam agar tidak serempak
	if animated_sprite and animated_sprite.sprite_frames:
		var anim_name: String = animated_sprite.animation
		if anim_name == "" or not animated_sprite.sprite_frames.has_animation(anim_name):
			anim_name = "idle" if animated_sprite.sprite_frames.has_animation("idle") else "default"
		if animated_sprite.sprite_frames.has_animation(anim_name):
			var frame_count: int = animated_sprite.sprite_frames.get_frame_count(anim_name)
			if frame_count > 0:
				animated_sprite.play(anim_name)
				animated_sprite.frame = randi() % frame_count
				animated_sprite.frame_progress = randf()
		animated_sprite.speed_scale = randf_range(0.88, 1.15)

	_reset_chirp_timer()


func start_following(target: Node2D) -> void:
	start_following_with_offset(target, -30.0)


func start_following_with_offset(target: Node2D, custom_offset_x: float) -> void:
	target_node = target
	offset_x = custom_offset_x
	is_following = true
	position_history.clear()

	if is_instance_valid(target_node):
		last_player_x = target_node.global_position.x
		ground_y = target_node.global_position.y


func _physics_process(delta: float) -> void:
	# --- 0. LOGIKA SUARA ANAK AYAM ---
	chirp_timer += delta
	if chirp_timer >= next_chirp_time:
		play_random_chirp()
		_reset_chirp_timer()

	# Jika belum mengikuti player
	if not is_following or not is_instance_valid(target_node):
		_update_shadow()
		return

	# Catat jejak posisi MC tiap frame untuk menciptakan delay alami
	var now: float = Time.get_ticks_msec() / 1000.0
	var player_on_floor: bool = true
	if target_node is CharacterBody2D:
		player_on_floor = target_node.is_on_floor()

	if player_on_floor:
		ground_y = target_node.global_position.y

	position_history.append({
		"time": now,
		"pos": target_node.global_position,
		"ground_y": ground_y,
		"on_floor": player_on_floor
	})

	# Ambil posisi MC dari `follow_delay` detik yang lalu
	var delayed_pos: Vector2 = target_node.global_position
	var delayed_ground_y: float = ground_y
	var delayed_on_floor: bool = player_on_floor
	while position_history.size() > 1 and (now - position_history[0]["time"]) > follow_delay:
		position_history.pop_front()

	if not position_history.is_empty():
		delayed_pos = position_history[0]["pos"]
		delayed_ground_y = position_history[0]["ground_y"]
		delayed_on_floor = position_history[0]["on_floor"]

	ground_y = delayed_ground_y

	var player_x: float = delayed_pos.x
	var desired_x: float = player_x + offset_x
	var is_player_moving: bool = abs(player_x - last_player_x) > 0.3
	last_player_x = player_x

	# 1. ATUR TRANSISI STATE (Tidak jittering saat lompat)
	if is_player_moving or not delayed_on_floor:
		current_state = State.FOLLOWING_PLAYER
	else:
		if current_state == State.FOLLOWING_PLAYER:
			current_state = State.IDLE_WAIT
			idle_timer = randf_range(1.5, 3.0)

	# 2. EKSEKUSI PERGERAKAN BERDASARKAN STATE
	var is_moving: bool = false
	var move_dir: float = 0.0
	var y_smooth: float = 1.0 - exp(-22.0 * delta)

	match current_state:
		State.FOLLOWING_PLAYER:
			var dist_x: float = desired_x - global_position.x
			if abs(dist_x) > 2.0:
				move_dir = sign(dist_x)
				global_position.x = move_toward(global_position.x, desired_x, follow_speed * delta)
				is_moving = true

			global_position.y = lerp(global_position.y, delayed_pos.y, y_smooth)

		State.IDLE_WAIT:
			global_position.y = lerp(global_position.y, delayed_ground_y, y_smooth)
			idle_timer -= delta
			if idle_timer <= 0.0:
				wander_target_x = desired_x + randf_range(-25.0, 25.0)
				current_state = State.IDLE_WANDER

		State.IDLE_WANDER:
			global_position.y = lerp(global_position.y, delayed_ground_y, y_smooth)
			idle_timer -= delta
			var wander_dist: float = wander_target_x - global_position.x

			if abs(wander_dist) > 2.0 and idle_timer > -3.0:
				move_dir = sign(wander_dist)
				global_position.x = move_toward(global_position.x, wander_target_x, wander_speed * delta)
				is_moving = true
			else:
				current_state = State.IDLE_WAIT
				idle_timer = randf_range(2.0, 4.5)

	# 3. UPDATE BAYANGAN (TETAP DI TANAH SAAT ANAK AYAM MELOMPAT)
	_update_shadow()

	# 4. KONTROL ANIMASI & FLIP SPRITE (Animasi tetap jalan saat idle)
	if animated_sprite:
		if is_moving:
			if move_dir != 0.0:
				animated_sprite.flip_h = (move_dir < 0.0)

			if animated_sprite.sprite_frames.has_animation("walk"):
				if animated_sprite.animation != "walk" or not animated_sprite.is_playing():
					animated_sprite.play("walk")
			elif animated_sprite.sprite_frames.has_animation("default"):
				if animated_sprite.animation != "default" or not animated_sprite.is_playing():
					animated_sprite.play("default")
		else:
			if animated_sprite.sprite_frames.has_animation("idle"):
				if animated_sprite.animation != "idle" or not animated_sprite.is_playing():
					animated_sprite.play("idle")
			elif animated_sprite.sprite_frames.has_animation("default"):
				if animated_sprite.animation != "default" or not animated_sprite.is_playing():
					animated_sprite.play("default")


func _update_shadow() -> void:
	if not shadow:
		return

	# Kunci posisi Y bayangan di tanah (ground_y + offset bawaan di scene)
	shadow.global_position.x = global_position.x
	shadow.global_position.y = ground_y + shadow_offset_y

	# Kecilkan sedikit ukuran bayangan saat anak ayam melompat tinggi
	var height_above_ground: float = max(0.0, ground_y - global_position.y)
	var scale_factor: float = clamp(1.0 - (height_above_ground / 120.0), 0.55, 1.0)
	shadow.scale = Vector2(scale_factor, scale_factor)


func collect() -> void:
	if GameManager and GameManager.has_method("collect_chick"):
		GameManager.collect_chick(chick_id)
	queue_free()


func play_random_chirp() -> void:
	if audio_player and audio_player.stream:
		audio_player.pitch_scale = randf_range(0.9, 1.3)
		audio_player.play()


func _reset_chirp_timer() -> void:
	chirp_timer = 0.0
	next_chirp_time = randf_range(min_chirp_interval, max_chirp_interval)
