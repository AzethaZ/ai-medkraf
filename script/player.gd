class_name Player
extends CharacterBody2D

# Kecepatan Pergerakan
const WALK_SPEED = 130.0
const RUN_SPEED = 250.0  # Kecepatan saat lari
const JUMP_VELOCITY = -300.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# 1. Tambahkan Gravitasi
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Penanganan Lompat
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Cek Tombol Shift (Lari)
	var current_speed = WALK_SPEED
	if Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT):
		current_speed = RUN_SPEED

	# 4. Ambil Arah Input (-1, 0, 1)
	var direction := Input.get_axis("ui_left", "ui_right")
	
	# 5. Flip Sprite (Balik Hadap)
	if direction > 0:
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		animated_sprite_2d.flip_h = true
	
	# 6. Putar Animasi
	if is_on_floor():
		if direction == 0:
			animated_sprite_2d.play("default")
		else:
			animated_sprite_2d.play("run")
			# Menyesuaikan kecepatan gerakan kaki dengan kecepatan jalan/lari
			animated_sprite_2d.speed_scale = 1.8 if current_speed == RUN_SPEED else 1.0
	else:
		animated_sprite_2d.play("jumping")
		animated_sprite_2d.speed_scale = 1.0
	
	# 7. Eksekusi Pergerakan Horizontal
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()
