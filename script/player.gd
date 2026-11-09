class_name Player
extends CharacterBody2D

# Kecepatan Pergerakan & Fisika
const WALK_SPEED = 130.0
const RUN_SPEED = 250.0 # Kecepatan saat lari
const LIMP_SPEED = 80.0  # Kecepatan saat jalan pincang/terluka
var JUMP_VELOCITY: float = -320.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Referensi Node DialogueUI
@onready var dialogue_ui: Control = find_child("DialogueUI", true, false)
@onready var dialogue_label: Label = find_child("Label", true, false)

# Referensi Node Audio Langkah Kaki
@onready var footstep_sound: AudioStreamPlayer = $FootstepSound if has_node("FootstepSound") else null

# Referensi Audio Batuk
@onready var cough_sound_1: AudioStreamPlayer = $CoughSound1 if has_node("CoughSound1") else null
@onready var cough_sound_2: AudioStreamPlayer = $CoughSound2 if has_node("CoughSound2") else null

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
var is_auto_walking: bool = false
var auto_walk_direction: float = 1.0
var is_chasing_mode: bool = false
var is_jumping: bool = false

# Timer Batuk Random
var cough_timer: float = 0.0
var min_cough_interval: float = 3.0 # Minimal jeda batuk (3 detik)
var max_cough_interval: float = 7.0 # Maksimal jeda batuk (7 detik)

var is_in_cutscene: bool = false
var cutscene_direction: float = 0.0
var can_move: bool = true

# --- STATUS MODIFIER TERLUKA / PINCANG ---
var is_limping: bool = false

# SISTEM ANTREAN ANAK AYAM (FOLLOWERS)
var followers: Array[Node2D] = []

# PENGATURAN SFX LANGKAH KAKI
var footstep_cooldown: float = 0.48 # Jeda antar langkah saat berjalan santai
var footstep_timer: float = 0.0


func _ready() -> void:
	# Beri sedikit jeda (0.05 detik) agar posisi Player sudah fix dipindahkan oleh script pemicu scene
	get_tree().create_timer(0.05).timeout.connect(restore_followers_on_scene_load)


func _physics_process(delta: float) -> void:
	# Jika sedang memutar animasi cutscene, lewati logika animasi otomatis player
	if is_in_cutscene_anim:
		return
	# 1. Gravitasi Udara
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. LOGIKA CUTSCENE IN-GAME
	if is_in_cutscene:
		var active_cutscene_speed = LIMP_SPEED if is_limping else WALK_SPEED
		velocity.x = cutscene_direction * active_cutscene_speed

		if cutscene_direction > 0:
			animated_sprite_2d.flip_h = false
		elif cutscene_direction < 0:
			animated_sprite_2d.flip_h = true

		if is_on_floor():
			if cutscene_direction != 0:
				animated_sprite_2d.play("walk")
				animated_sprite_2d.speed_scale = 0.5 if is_limping else 1.0
			else:
				animated_sprite_2d.play("default")
				animated_sprite_2d.speed_scale = 1.0

		handle_footstep_sound(delta, active_cutscene_speed)
		move_and_slide()
		return

	# 3. KONTROL MANUAL DIMATIKAN (Hanya aktif jika BUKAN cutscene & BUKAN chase/auto-walk)
	if not can_move and not is_chasing_mode and not is_auto_walking:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		if is_on_floor():
			animated_sprite_2d.play("default")
			animated_sprite_2d.speed_scale = 1.0
		handle_footstep_sound(delta, 0.0)
		move_and_slide()
		return

	# 4. LOGIKA LOMPAT (Spacebar / ui_up / ui_accept)
	var wants_jump = Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")
	if wants_jump and is_on_floor():
		if is_chasing_mode or is_auto_walking or not is_limping:
			velocity.y = JUMP_VELOCITY

	# 5. KEKUATAN LARI / JALAN
	var current_speed = WALK_SPEED
	if is_limping:
		current_speed = LIMP_SPEED
	else:
		if Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT):
			current_speed = RUN_SPEED
		else:
			current_speed = WALK_SPEED

	# 6. AMBIL INPUT DIRECTION (-1, 0, 1)
	var direction := Input.get_axis("ui_left", "ui_right")

	# 7. GERAKAN HORIZONTAL & FLIP SPRITE
	if is_chasing_mode:
		# Posisi X dikunci di tengah layar khusus mode kejar-kejaran
		velocity.x = 0
		animated_sprite_2d.flip_h = false
	elif is_auto_walking:
		# Saat Auto Walk: Jalan otomatis ke kanan pakai auto_walk_direction
		velocity.x = auto_walk_direction * WALK_SPEED
		animated_sprite_2d.flip_h = (auto_walk_direction < 0)
	elif can_move:
		if direction > 0:
			animated_sprite_2d.flip_h = false
		elif direction < 0:
			animated_sprite_2d.flip_h = true

		if direction != 0:
			velocity.x = direction * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
	else:
		velocity.x = 0

	# Eksekusi pergerakan fisika
	move_and_slide()

	# 8. KONTROL ANIMASI (HOLD KANAN SAAT CHASE & TRANSISI LOMPAT)
	if is_on_floor():
		if is_chasing_mode:
			# Jika sedang menahan tombol KANAN (D / Panah Kanan) -> Animasi RUN
			if Input.is_action_pressed("ui_right"):
				if animated_sprite_2d.animation != "run":
					animated_sprite_2d.play("run")
				animated_sprite_2d.speed_scale = 1.0
			else:
				if animated_sprite_2d.animation != "default":
					animated_sprite_2d.play("default")
				animated_sprite_2d.speed_scale = 1.0
		elif is_auto_walking:
			if animated_sprite_2d.animation != "walk":
				animated_sprite_2d.play("walk")
			animated_sprite_2d.speed_scale = 1.0
		elif velocity.x == 0:
			animated_sprite_2d.play("walk" if is_limping else "default")
			animated_sprite_2d.speed_scale = 0.5 if is_limping else 1.0
		else:
			if is_limping:
				animated_sprite_2d.play("walk")
				animated_sprite_2d.speed_scale = 0.5
			elif current_speed == RUN_SPEED:
				animated_sprite_2d.play("run")
				animated_sprite_2d.speed_scale = 1.0
			else:
				animated_sprite_2d.play("walk")
				animated_sprite_2d.speed_scale = 1.0
	else:
		# --- TRANSISI UDARA 3 STAGE (Rise -> Mid -> Fall) ---
		animated_sprite_2d.speed_scale = 1.0
		if velocity.y < -50.0:
			if animated_sprite_2d.sprite_frames.has_animation("jump_rise"):
				animated_sprite_2d.play("jump_rise")
			elif animated_sprite_2d.sprite_frames.has_animation("Rise"):
				animated_sprite_2d.play("Rise")
			elif animated_sprite_2d.sprite_frames.has_animation("jumping"):
				animated_sprite_2d.play("jumping")

		elif velocity.y >= -50.0 and velocity.y <= 50.0:
			if animated_sprite_2d.sprite_frames.has_animation("jump_mid"):
				animated_sprite_2d.play("jump_mid")
			elif animated_sprite_2d.sprite_frames.has_animation("Mid"):
				animated_sprite_2d.play("Mid")
			elif animated_sprite_2d.sprite_frames.has_animation("jumping"):
				animated_sprite_2d.play("jumping")

		else:
			if animated_sprite_2d.sprite_frames.has_animation("jump_fall"):
				animated_sprite_2d.play("jump_fall")
			elif animated_sprite_2d.sprite_frames.has_animation("Fall"):
				animated_sprite_2d.play("Fall")
			elif animated_sprite_2d.sprite_frames.has_animation("falling"):
				animated_sprite_2d.play("falling")

	# Memutar SFX Langkah kaki dan batuk
	var sfx_speed = WALK_SPEED if (is_chasing_mode and Input.is_action_pressed("ui_right")) or is_auto_walking else velocity.x
	handle_footstep_sound(delta, abs(sfx_speed))
	handle_cough_logic(delta)


func handle_footstep_sound(delta: float, speed: float) -> void:
	if not is_on_floor() or speed <= 0:
		footstep_timer = 0.0
		return

	footstep_timer -= delta
	if footstep_timer <= 0:
		if footstep_sound and footstep_sound.stream:
			if is_limping:
				footstep_sound.pitch_scale = randf_range(0.7, 0.9)
			else:
				footstep_sound.pitch_scale = randf_range(1.1, 1.5)
			footstep_sound.play()
		footstep_timer = footstep_cooldown


# --- FUNGSI HELPER UNTUK MODE PINCANG, CUTSCENE & DIALOG ---
func set_limping_mode(enabled: bool) -> void:
	is_limping = enabled
	if is_limping:
		# Acak timer batuk pertama kali
		cough_timer = randf_range(min_cough_interval, max_cough_interval)


func start_auto_walk(dir: float = 1.0) -> void:
	is_auto_walking = true
	auto_walk_direction = dir
	can_move = false


func stop_auto_walk() -> void:
	is_auto_walking = false
	can_move = true
	if animated_sprite_2d and animated_sprite_2d.sprite_frames.has_animation("default"):
		animated_sprite_2d.play("default")


func disable_movement() -> void:
	can_move = false


func enable_movement() -> void:
	can_move = true


func show_dialogue(text: String, duration: float = 2.5) -> void:
	if dialogue_ui and dialogue_label:
		dialogue_label.text = text
		dialogue_label.visible_characters = 0
		dialogue_ui.show()

		var text_length: int = text.length()
		var type_speed: float = text_length * 0.04

		var text_tween: Tween = create_tween()
		text_tween.tween_property(dialogue_label, "visible_characters", text_length, type_speed)
		await text_tween.finished

		await get_tree().create_timer(duration).timeout
		dialogue_ui.hide()
	else:
		print("Danum: ", text)
		await get_tree().create_timer(duration).timeout


func restore_followers_on_scene_load() -> void:
	if GameManager and GameManager.follower_count > 0:
		var spawn_offset_x: float = -40.0
		var animated_sprite = find_child("AnimatedSprite2D", true, false)
		if animated_sprite and animated_sprite.flip_h:
			spawn_offset_x = 40.0

		for i in range(GameManager.follower_count):
			if GameManager.chick_follower_scene:
				var new_chick = GameManager.chick_follower_scene.instantiate() as Node2D

				new_chick.global_position = Vector2(
					global_position.x + (spawn_offset_x * (i + 1)),
					global_position.y
				)

				get_tree().current_scene.add_child(new_chick)
				add_follower(new_chick)


func add_follower(follower_node: Node2D) -> void:
	if not followers.has(follower_node):
		followers.append(follower_node)

		var index = followers.size() - 1
		var side_offset = 28.0 + (int(index / 2.0) * 20.0)
		if index % 2 == 1:
			side_offset = -side_offset

		if follower_node.has_method("start_following_with_offset"):
			follower_node.start_following_with_offset(self, side_offset)


func clear_followers() -> void:
	for follower in followers:
		if is_instance_valid(follower):
			follower.queue_free()
	followers.clear()

	if GameManager.has_method("clear_followers_data"):
		GameManager.clear_followers_data()


func set_dialogue_state(is_talking: bool) -> void:
	if is_talking:
		velocity = Vector2.ZERO
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("default")
			$AnimatedSprite2D.speed_scale = 1.0
		elif has_node("AnimationPlayer"):
			var anim_player = $AnimationPlayer
			if anim_player.has_animation("default"):
				anim_player.play("default")

		set_physics_process(false)
	else:
		set_physics_process(true)


func handle_cough_logic(delta: float) -> void:
	if not is_limping:
		return

	cough_timer += delta
	if cough_timer >= max_cough_interval:
		cough_timer = 0.0
		play_random_cough()


func play_random_cough() -> void:
	var cough_sounds = []
	if cough_sound_1:
		cough_sounds.append(cough_sound_1)
	if cough_sound_2:
		cough_sounds.append(cough_sound_2)

	if cough_sounds.size() > 0:
		var selected_sound: AudioStreamPlayer = cough_sounds.pick_random()
		selected_sound.pitch_scale = randf_range(0.9, 1.1)
		selected_sound.play()

var is_in_cutscene_anim: bool = false

func play_cutscene_walk() -> void:
	is_in_cutscene_anim = true
	var sprite = find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")

func play_cutscene_idle() -> void:
	is_in_cutscene_anim = false
	var sprite = find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
		sprite.play("default")
