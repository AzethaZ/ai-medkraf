extends CharacterBody2D

# ID Unik Anak Ayam (Set di Inspector Godot untuk tiap ayam)
@export var chick_id: String = "chick_1" 

@export var follow_speed: float = 120.0
@export var wander_speed: float = 40.0 # Kecepatan lebih santai saat geser idlenya

var target_node: Node2D = null
var is_following: bool = false
var offset_x: float = 0.0

# State Management untuk Idle Wander
enum State { FOLLOWING_PLAYER, IDLE_WAIT, IDLE_WANDER }
var current_state: State = State.IDLE_WAIT

var idle_timer: float = 0.0
var wander_target_x: float = 0.0
var last_player_x: float = 0.0

# Referensi Node
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer if has_node("AudioStreamPlayer") else null

# Timer Suara Acak Anak Ayam
var chirp_timer: float = 0.0
var min_chirp_interval: float = 3.0
var max_chirp_interval: float = 7.0
var next_chirp_time: float = 0.0


func _ready() -> void:
	# Cek apakah ayam ini sudah pernah diambil sebelumnya di QuestManager
	if QuestManager and QuestManager.has_method("is_chick_collected"):
		if QuestManager.is_chick_collected(chick_id):
			queue_free()
			return

	_reset_chirp_timer()


func start_following(new_target: Node2D) -> void:
	start_following_with_offset(new_target, -30.0)


func start_following_with_offset(new_target: Node2D, custom_offset_x: float) -> void:
	target_node = new_target
	offset_x = custom_offset_x
	is_following = true
	if is_instance_valid(target_node):
		last_player_x = target_node.global_position.x


func _physics_process(delta: float) -> void:
	# --- LOGIKA SUARA ACAK ---
	chirp_timer += delta
	if chirp_timer >= next_chirp_time:
		play_random_chirp()
		_reset_chirp_timer()

	# Cek apakah sedang mengikuti target
	if not is_following or not is_instance_valid(target_node):
		return

	# Kunci posisi Y sejajar dengan player
	global_position.y = target_node.global_position.y

	var player_x = target_node.global_position.x
	var desired_base_x = player_x + offset_x
	var dist_to_base = abs(desired_base_x - global_position.x)

	# Cek apakah Danum sedang berjalan jauh
	var is_player_moving = abs(player_x - last_player_x) > 0.5
	last_player_x = player_x

	# 1. LOGIKA PILIH STATE
	if is_player_moving or dist_to_base > 45.0:
		current_state = State.FOLLOWING_PLAYER
	else:
		if current_state == State.FOLLOWING_PLAYER:
			current_state = State.IDLE_WAIT
			idle_timer = randf_range(1.0, 2.5)

	# 2. EKSEKUSI PERGERAKAN BERDASARKAN STATE
	var is_moving: bool = false
	var move_dir: float = 0.0

	match current_state:
		State.FOLLOWING_PLAYER:
			var x_dist = desired_base_x - global_position.x
			if abs(x_dist) > 4.0:
				move_dir = sign(x_dist)
				global_position.x = move_toward(global_position.x, desired_base_x, follow_speed * delta)
				is_moving = true

		State.IDLE_WAIT:
			idle_timer -= delta
			if idle_timer <= 0.0:
				wander_target_x = desired_base_x + randf_range(-25.0, 25.0)
				idle_timer = randf_range(1.5, 3.0)
				current_state = State.IDLE_WANDER

		State.IDLE_WANDER:
			idle_timer -= delta
			var wander_dist = wander_target_x - global_position.x

			if abs(wander_dist) > 3.0 and idle_timer > 0.0:
				move_dir = sign(wander_dist)
				global_position.x = move_toward(global_position.x, wander_target_x, wander_speed * delta)
				is_moving = true
			else:
				current_state = State.IDLE_WAIT
				idle_timer = randf_range(2.0, 4.0)

	# 3. KONTROL ANIMASI & FLIP SPRITE
	if animated_sprite:
		if is_moving:
			if move_dir != 0:
				animated_sprite.flip_h = (move_dir < 0)

			if animated_sprite.sprite_frames.has_animation("walk"):
				if animated_sprite.animation != "walk" or not animated_sprite.is_playing():
					animated_sprite.play("walk")
			elif animated_sprite.sprite_frames.has_animation("default"):
				if not animated_sprite.is_playing():
					animated_sprite.play("default")
		else:
			if animated_sprite.sprite_frames.has_animation("idle"):
				if animated_sprite.animation != "idle" or not animated_sprite.is_playing():
					animated_sprite.play("idle")
			elif animated_sprite.sprite_frames.has_animation("default"):
				if not animated_sprite.is_playing():
					animated_sprite.play("default")
			else:
				animated_sprite.stop()


# --- FUNGSI TANGKAP AYAM ---
func collect() -> void:
	if QuestManager and QuestManager.has_method("collect_chick"):
		QuestManager.collect_chick(chick_id)
	queue_free()


# --- FUNGSI AUDIO SUARA ACAK ---
func play_random_chirp() -> void:
	if audio_player and audio_player.stream:
		audio_player.pitch_scale = randf_range(0.9, 1.3)
		audio_player.play()


func _reset_chirp_timer() -> void:
	chirp_timer = 0.0
	next_chirp_time = randf_range(min_chirp_interval, max_chirp_interval)
