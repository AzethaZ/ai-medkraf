class_name Player
extends CharacterBody2D

# Kecepatan Pergerakan
const WALK_SPEED = 130.0
const RUN_SPEED = 250.0 # Kecepatan saat lari
const JUMP_VELOCITY = -300.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Referensi Node DialogueUI
@onready var dialogue_ui: Control = find_child("DialogueUI", true, false)
@onready var dialogue_label: Label = find_child("Label", true, false)

# Variabel Tambahan untuk Cutscene In-Game
var is_in_cutscene: bool = false
var cutscene_direction: float = 0.0
var can_move: bool = true

# SISTEM ANTREAN ANAK AYAM (FOLLOWERS)
var followers: Array[Node2D] = []

func _ready() -> void:
	# Beri sedikit jeda (0.05 detik) agar posisi Player sudah fix dipindahkan oleh script pemicu scene
	get_tree().create_timer(0.05).timeout.connect(restore_followers_on_scene_load)

func _physics_process(delta: float) -> void:
	# 1. Tambahkan Gravitasi
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- LOGIKA CUTSCENE IN-GAME ---
	if is_in_cutscene:
		velocity.x = cutscene_direction * WALK_SPEED
		
		if cutscene_direction > 0:
			animated_sprite_2d.flip_h = false
		elif cutscene_direction < 0:
			animated_sprite_2d.flip_h = true

		if is_on_floor():
			if cutscene_direction != 0:
				animated_sprite_2d.play("walk")
				animated_sprite_2d.speed_scale = 1.0
			else:
				animated_sprite_2d.play("default")

		move_and_slide()
		return

	# Jika kontrol manual sedang dimatikan
	if not can_move:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		if is_on_floor():
			animated_sprite_2d.play("default")
		move_and_slide()
		return

	# 2. Cek Tombol Shift (Lari)
	var current_speed = WALK_SPEED
	if Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT):
		current_speed = RUN_SPEED

	# 3. Ambil Arah Input (-1, 0, 1)
	var direction := Input.get_axis("ui_left", "ui_right")

	# 4. Flip Sprite (Balik Hadap)
	if direction > 0:
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		animated_sprite_2d.flip_h = true

	# 5. Putar Animasi
	if is_on_floor():
		if direction == 0:
			animated_sprite_2d.play("default")
		else:
			if current_speed == RUN_SPEED:
				animated_sprite_2d.play("run")
			else:
				animated_sprite_2d.play("walk")
				animated_sprite_2d.speed_scale = 1.0
	else:
		animated_sprite_2d.play("jumping")
		animated_sprite_2d.speed_scale = 1.0

	# 6. Eksekusi Pergerakan Horizontal
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()

# -----------------------------------
# FUNGSI HELPER UNTUK CUTSCENE & DIALOG
# -----------------------------------
func start_auto_walk(dir: float = 1.0) -> void:
	is_in_cutscene = true
	cutscene_direction = dir

func stop_auto_walk() -> void:
	is_in_cutscene = false
	cutscene_direction = 0.0
	if animated_sprite_2d and is_on_floor():
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
		# Tentukan offset spawn berdasarkan arah hadap Player (Sprite2D / AnimatedSprite2D)
		var spawn_offset_x: float = -40.0
		var animated_sprite = find_child("AnimatedSprite2D", true, false)
		if animated_sprite and animated_sprite.flip_h:
			spawn_offset_x = 40.0

		for i in range(GameManager.follower_count):
			if GameManager.chick_follower_scene:
				var new_chick = GameManager.chick_follower_scene.instantiate() as Node2D
				
				# Pasang posisi spawn LANGSUNG di koordinat akhir Player
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
		# Jika genap spawn di kanan, jika ganjil spawn di kiri
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
