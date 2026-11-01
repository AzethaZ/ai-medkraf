class_name Player
extends CharacterBody2D

# Kecepatan Pergerakan
const WALK_SPEED = 130.0
const RUN_SPEED = 250.0 # Kecepatan saat lari
const JUMP_VELOCITY = -300.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Variabel Tambahan untuk Cutscene In-Game
var is_in_cutscene: bool = false
var cutscene_direction: float = 0.0

func _physics_process(delta: float) -> void:
	# 1. Tambahkan Gravitasi (Berlaku saat cutscene maupun gameplay)
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- LOGIKA CUTSCENE IN-GAME ---
	if is_in_cutscene:
		velocity.x = cutscene_direction * WALK_SPEED
		
		# Animasi & Balik Hadap saat Cutscene
		if cutscene_direction > 0:
			animated_sprite_2d.flip_h = false
		elif cutscene_direction < 0:
			animated_sprite_2d.flip_h = true
			
		if is_on_floor():
			if cutscene_direction != 0:
				animated_sprite_2d.play("run") # Atau sesuaikan jika ada animasi "walk"
				animated_sprite_2d.speed_scale = 1.0
			else:
				animated_sprite_2d.play("default")
		
		move_and_slide()
		return # Stop eksekusi agar input player di bawah tidak berjalan

	# --- 2. Penanganan Lompat ---
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- 3. Cek Tombol Shift (Lari) ---
	var current_speed = WALK_SPEED
	if Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT):
		current_speed = RUN_SPEED

	# --- 4. Ambil Arah Input (-1, 0, 1) ---
	var direction := Input.get_axis("ui_left", "ui_right")

	# --- 5. Flip Sprite (Balik Hadap) ---
	if direction > 0:
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		animated_sprite_2d.flip_h = true

	# --- 6. Putar Animasi ---
	if is_on_floor():
		if direction == 0:
			animated_sprite_2d.play("default")
		else:
			animated_sprite_2d.play("run")
			animated_sprite_2d.speed_scale = 1.8 if current_speed == RUN_SPEED else 1.0
	else:
		animated_sprite_2d.play("jumping")
		animated_sprite_2d.speed_scale = 1.0

	# --- 7. Eksekusi Pergerakan Horizontal ---
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()

# --- FUNGSI HELPER UNTUK CUTSCENE ---
func start_auto_walk(dir: float = 1.0) -> void:
	is_in_cutscene = true
	cutscene_direction = dir

func stop_auto_walk() -> void:
	is_in_cutscene = false
	cutscene_direction = 0.0
	if animated_sprite_2d and is_on_floor():
		animated_sprite_2d.play("default")
