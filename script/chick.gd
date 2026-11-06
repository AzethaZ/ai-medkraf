extends CharacterBody2D

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

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func start_following(new_target: Node2D) -> void:
	start_following_with_offset(new_target, -30.0)

func start_following_with_offset(new_target: Node2D, custom_offset_x: float) -> void:
	target_node = new_target
	offset_x = custom_offset_x
	is_following = true
	if is_instance_valid(target_node):
		last_player_x = target_node.global_position.x

func _physics_process(delta: float) -> void:
	if not is_following or not is_instance_valid(target_node):
		return

	# Kunci posisi Y sejajar dengan player
	global_position.y = target_node.global_position.y

	var player_x = target_node.global_position.x
	var desired_base_x = player_x + offset_x
	var dist_to_base = abs(desired_base_x - global_position.x)

	# Cek apakah Danum sedang berjalan jauh (selisih posisi player berubah)
	var is_player_moving = abs(player_x - last_player_x) > 0.5
	last_player_x = player_x

	# 1. LOGIKA PILIH STATE
	if is_player_moving or dist_to_base > 45.0:
		# Jika Danum jalan / anak ayam ketinggalan jauh -> Fokus kejar Danum
		current_state = State.FOLLOWING_PLAYER
	else:
		# Jika Danum diam di tempat -> Jalankan rutinitas santai (Wait <-> Wander)
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
				# Saat jeda diam selesai, tentukan target titik geser baru (jarak hingga 25px)
				wander_target_x = desired_base_x + randf_range(-25.0, 25.0)
				idle_timer = randf_range(1.5, 3.0) # Durasi maksimum batas waktu jalan
				current_state = State.IDLE_WANDER

		State.IDLE_WANDER:
			idle_timer -= delta
			var wander_dist = wander_target_x - global_position.x

			if abs(wander_dist) > 3.0 and idle_timer > 0.0:
				move_dir = sign(wander_dist)
				global_position.x = move_toward(global_position.x, wander_target_x, wander_speed * delta)
				is_moving = true
			else:
				# Setelah sampai di titik geser -> Berhenti & diam sejenak
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
			# Saat diam menunggu (IDLE_WAIT)
			if animated_sprite.sprite_frames.has_animation("idle"):
				if animated_sprite.animation != "idle" or not animated_sprite.is_playing():
					animated_sprite.play("idle")
			elif animated_sprite.sprite_frames.has_animation("default"):
				if not animated_sprite.is_playing():
					animated_sprite.play("default")
			else:
				animated_sprite.stop()
