extends Control

signal minigame_completed(success: bool)
signal player_damaged()
signal rooster_damaged()

var key_textures: Dictionary = {}
var possible_keys: Array[String] = ["w", "a", "s", "d", "interact"]
var current_sequence: Array[String] = []
var current_input_index: int = 0
var sequence_length: int = 4

var score_count: int = 0
var target_score: int = 7  # Total 7 ronde

var time_limit: float = 3.0
var current_timer: float = 0.0
var is_active: bool = false
var target_player: Node2D = null

var strike_count: int = 0
var max_strikes: int = 3  # Jatah salah 3 kali pada fase attack

var is_spam_phase: bool = false
var spam_progress: float = 0.0
var spam_target: float = 100.0
var spam_decay_rate: float = 22.0
var can_proceed_next: bool = true

@onready var sequence_container: HBoxContainer = $PanelContainer/VBoxContainer/SequenceContainer if has_node("PanelContainer/VBoxContainer/SequenceContainer") else null
@onready var red_bar: Control = $PanelContainer/VBoxContainer/BarWrapper/RedBar if has_node("PanelContainer/VBoxContainer/BarWrapper/RedBar") else null
@onready var background_bar: Control = $PanelContainer/VBoxContainer/BarWrapper/BackgroundBar if has_node("PanelContainer/VBoxContainer/BarWrapper/BackgroundBar") else null
@onready var panel_container: PanelContainer = $PanelContainer if has_node("PanelContainer") else null

@export_group("Battle SFX")
@export var player_attack_sfx: AudioStream   # Drag file suara pukulan Danum ke sini di Inspector
@export var rooster_attack_sfx: AudioStream  # Drag file suara serangan/kokokan Rooster ke sini di Inspector
@export var attack_sfx_volume_db: float = 0.0

@export_group("Battle BGM")
@export var battle_bgm: AudioStream          # Drag file musik battle ke sini di Inspector
@export var battle_bgm_volume_db: float = -4.0

@export var key_correct_sfx: AudioStream     # Drag file SFX tombol benar (misal pop.mp3 / click) ke sini
@export var game_over_sfx: AudioStream       # Drag file SFX game over ke sini di Inspector

@export var spam_e_texture: Texture2D
@onready var spam_e_sprite: AnimatedSprite2D = find_child("SpamESprite", true, false)

@export_group("QTE SFX")
@export var wrong_sfx: AudioStream
@export var wrong_sfx_volume: float = 0.0

var wrong_sfx_player: AudioStreamPlayer

var _previous_bgm: AudioStream = null
var _previous_bgm_volume: float = -5.0

var default_bar_pos_x: float = 0.0
var full_bar_width: float = 180.0


func _ready() -> void:
	wrong_sfx_player = AudioStreamPlayer.new()
	wrong_sfx_player.volume_db = wrong_sfx_volume
	add_child(wrong_sfx_player)
	if spam_e_sprite:
		spam_e_sprite.visible = false
		spam_e_sprite.stop()
	visible = false
	is_active = false
	load_textures()
	if background_bar:
		default_bar_pos_x = background_bar.position.x
		full_bar_width = background_bar.size.x if background_bar.size.x > 0 else 180.0


func load_textures() -> void:
	key_textures = {
		"w": load("res://assets/animation/ui/Atas.png") if ResourceLoader.exists("res://assets/animation/ui/Atas.png") else null,
		"a": load("res://assets/animation/ui/kiri.png") if ResourceLoader.exists("res://assets/animation/ui/kiri.png") else null,
		"s": load("res://assets/animation/ui/Bawah.png") if ResourceLoader.exists("res://assets/animation/ui/Bawah.png") else null,
		"d": load("res://assets/animation/ui/Kanan.png") if ResourceLoader.exists("res://assets/animation/ui/Kanan.png") else null,
		"interact": load("res://assets/animation/ui/button1.png") if ResourceLoader.exists("res://assets/animation/ui/button1.png") else null
	}


func start_minigame(player_node: Node2D = null) -> void:
	target_player = player_node
	if not is_instance_valid(target_player):
		target_player = get_tree().current_scene.find_child("Player", true, false)

	score_count = 0
	strike_count = 0
	visible = true
	is_active = true
	can_proceed_next = true

	_set_player_fighting_stance(true)
	_start_battle_bgm()
	next_round()


func next_round() -> void:
	if score_count >= target_score:
		finish_minigame(true)
		return

	current_input_index = 0
	can_proceed_next = true

	var bar_width_ratio = 1.0
	if score_count == 1 or score_count == 3 or score_count == 5:
		is_spam_phase = true
		spam_progress = spam_target * 0.25
		generate_spam_display()
		bar_width_ratio = 0.75
		if red_bar:
			red_bar.scale.x = (spam_progress / spam_target) * bar_width_ratio
	else:
		is_spam_phase = false
		
		if score_count == 0:
			sequence_length = 3
			time_limit = 4.0
		elif score_count == 2:
			sequence_length = 4
			time_limit = 5.0
		elif score_count == 4:
			sequence_length = 4
			time_limit = 5.0
		elif score_count == 6:
			sequence_length = 5
			time_limit = 6.0
			
		current_timer = time_limit
		bar_width_ratio = 1.0
			
		generate_random_sequence()
		update_sequence_display()
		
		if red_bar:
			red_bar.scale.x = 1.0

	if background_bar:
		background_bar.scale.x = bar_width_ratio
		var width_diff = full_bar_width * (1.0 - bar_width_ratio)
		background_bar.position.x = default_bar_pos_x + (width_diff / 2.0)
	
	if red_bar:
		var width_diff = full_bar_width * (1.0 - bar_width_ratio)
		red_bar.position.x = default_bar_pos_x + (width_diff / 2.0)


func generate_random_sequence() -> void:
	if spam_e_sprite:
		spam_e_sprite.visible = false
		spam_e_sprite.stop()
	current_sequence.clear()
	for i in range(sequence_length):
		current_sequence.append(possible_keys.pick_random())


func generate_spam_display() -> void:
	if sequence_container:
		for child in sequence_container.get_children():
			child.queue_free()

	if spam_e_sprite:
		spam_e_sprite.visible = true
		if spam_e_sprite.sprite_frames:
			var anim_names := spam_e_sprite.sprite_frames.get_animation_names()
			if anim_names.size() > 0:
				spam_e_sprite.play(anim_names[0])


func update_sequence_display() -> void:
	if not sequence_container:
		return

	for child in sequence_container.get_children():
		child.queue_free()

	for i in range(current_sequence.size()):
		var key_code = current_sequence[i]
		var texture_to_use: Texture2D = key_textures.get(key_code, null)

		if texture_to_use != null:
			var rect = TextureRect.new()
			rect.texture = texture_to_use
			rect.custom_minimum_size = Vector2(28, 28)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

			if i < current_input_index:
				rect.modulate = Color(1.0, 1.0, 1.0, 0.0) # Hilang (transparan) tapi tetap menjaga ruang slot
			elif i == current_input_index:
				rect.modulate = Color(1.0, 1.0, 1.0, 1.0) # Panah aktif sekarang
			else:
				rect.modulate = Color(0.4, 0.4, 0.4, 0.5) # Panah antrean berikutnya

			sequence_container.add_child(rect)
		else:
			var label = Label.new()
			var fallback_map = {"W": "W", "A": "A", "S": "S", "D": "D", "interact": "[E]"}
			label.text = fallback_map.get(key_code, "[?]")
			label.custom_minimum_size = Vector2(28, 28)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			if i < current_input_index:
				label.modulate = Color(1.0, 1.0, 1.0, 0.0) # Hilang (transparan) tapi tetap menjaga ruang slot
			elif i == current_input_index:
				label.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				label.modulate = Color(0.4, 0.4, 0.4, 0.5)

			sequence_container.add_child(label)


func _process(delta: float) -> void:
	if not is_active:
		return

	if is_spam_phase and can_proceed_next:
		if spam_progress > 0.0:
			spam_progress -= spam_decay_rate * delta
			if spam_progress < 0.0:
				spam_progress = 0.0
			
			if red_bar:
				var spam_max_width_ratio = 0.75
				red_bar.scale.x = clamp((spam_progress / spam_target) * spam_max_width_ratio, 0.0, spam_max_width_ratio)

		if spam_progress <= 0.0:
			handle_block_fail()  # Gagal block langsung mati

	else:
		if can_proceed_next:
			current_timer -= delta
			if red_bar:
				red_bar.scale.x = clamp(current_timer / time_limit, 0.0, 1.0)

			if current_timer <= 0:
				handle_attack_fail()  # Waktu habis saat attack


func handle_block_fail() -> void:
	can_proceed_next = false
	play_error_flash_effect()
	# Gagal block langsung mengurangi semua nyawa / langsung game over
	strike_count = max_strikes
	player_damaged.emit()
	finish_minigame(false)


func handle_attack_fail() -> void:
	strike_count += 1
	play_error_flash_effect()
	player_damaged.emit()  # Kurangi 1 nyawa hati per kesalahan

	if strike_count >= max_strikes:
		can_proceed_next = false
		finish_minigame(false)
	else:
		current_timer = time_limit
		current_input_index = 0
		update_sequence_display()
		if red_bar:
			red_bar.scale.x = 1.0


func play_error_flash_effect() -> void:
	play_player_hit_effect(false)
	if wrong_sfx:
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.stream = wrong_sfx
		sfx_player.volume_db = wrong_sfx_volume
		add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)


func _input(event: InputEvent) -> void:
	if not is_active or not visible or not can_proceed_next:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var keycode_val = event.keycode if event.keycode != 0 else event.physical_keycode

		if is_spam_phase:
			if keycode_val == KEY_E or event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_play_sfx(key_correct_sfx)
				spam_progress += 10.0
				if spam_progress > spam_target:
					spam_progress = spam_target

				if red_bar:
					var spam_max_width_ratio = 0.75
					red_bar.scale.x = clamp((spam_progress / spam_target) * spam_max_width_ratio, 0.0, spam_max_width_ratio)

				if spam_progress >= spam_target:
					can_proceed_next = false
					handle_block_success()
			return

		if current_input_index >= current_sequence.size():
			return

		var target_key = current_sequence[current_input_index]
		var pressed_key_name: String = ""

		match keycode_val:
			KEY_W: pressed_key_name = "w"
			KEY_A: pressed_key_name = "a"
			KEY_S: pressed_key_name = "s"
			KEY_D: pressed_key_name = "d"
			KEY_E: pressed_key_name = "interact"

		if pressed_key_name == "":
			if event.is_action_pressed("ui_up"): pressed_key_name = "w"
			elif event.is_action_pressed("ui_left"): pressed_key_name = "a"
			elif event.is_action_pressed("ui_down"): pressed_key_name = "s"
			elif event.is_action_pressed("ui_right"): pressed_key_name = "d"
			elif event.is_action_pressed("interact"): pressed_key_name = "interact"

		if pressed_key_name != "":
			get_viewport().set_input_as_handled()

			if pressed_key_name != "":
				get_viewport().set_input_as_handled()

			if pressed_key_name == target_key:
				_play_sfx(key_correct_sfx)
				current_input_index += 1
				update_sequence_display()

				if current_input_index >= current_sequence.size():
					can_proceed_next = false
					handle_attack_success()
			else:
				handle_attack_fail()


func handle_block_success() -> void:
	_set_player_combat_anim("block") # Tetap pose block selama ayam menyerang & knockback
	await play_rooster_attack_anim()
	play_player_hit_effect()
	play_block_knockback()
	score_count += 1

	var transition_timer = get_tree().create_timer(1.0)
	transition_timer.timeout.connect(func():
		_reset_player_to_fighting() # Baru balik ke fighting setelah tween & jeda selesai
		next_round()
	)

func handle_attack_success() -> void:
	_set_player_combat_anim("attack") # Tetap pose attack selama chicken hit effect berlangsung
	_play_sfx(player_attack_sfx)
	play_chicken_hit_effect()
	score_count += 1
	rooster_damaged.emit()

	var transition_timer = get_tree().create_timer(1.0)
	transition_timer.timeout.connect(func():
		_reset_player_to_fighting() # Baru balik ke fighting setelah tween & jeda selesai
		next_round()
	)

func _set_player_combat_anim(anim_name: String) -> void:
	if not is_instance_valid(target_player):
		target_player = get_tree().current_scene.find_child("Player", true, false)
	if not is_instance_valid(target_player):
		return

	var sprite: AnimatedSprite2D = target_player.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func _reset_player_to_fighting() -> void:
	if not is_instance_valid(target_player):
		return
	var sprite: AnimatedSprite2D = target_player.get_node_or_null("AnimatedSprite2D")
	if is_active and sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("fighting"):
		sprite.play("fighting")

func play_chicken_hit_effect() -> void:
	var rooster_node = get_tree().current_scene.find_child("Rooster", true, false)
	if not rooster_node:
		rooster_node = get_tree().current_scene.find_child("rooster", true, false)

	if rooster_node:
		var r_sprite: CanvasItem = rooster_node.find_child("AnimatedSprite2D", true, false)
		if r_sprite:
			var mat := r_sprite.material as ShaderMaterial
			if not mat or not mat.shader:
				var shader := Shader.new()
				shader.code = """
shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, vec3(1.0), flash_amount), tex.a);
}
"""
				mat = ShaderMaterial.new()
				mat.shader = shader
				r_sprite.material = mat

			var orig_x: float = r_sprite.position.x
			var tween := create_tween()

			# 1. Langsung putih solid & DIAM MEMBEKU (hit-stop) selama 0.25 detik
			mat.set_shader_parameter("flash_amount", 1.0)
			tween.tween_interval(0.40)

			# 2. Setelah delay putih selesai, warna putih memudar sambil mulai bergoyang lambat
			tween.tween_method(
				func(val: float): mat.set_shader_parameter("flash_amount", val),
				1.0, 0.0, 0.25
			)
			tween.parallel().tween_property(r_sprite, "position:x", orig_x - 14.0, 0.16)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

			# 3. Lanjutan goyangan berat sampai kembali tenang ke posisi semula
			tween.tween_property(r_sprite, "position:x", orig_x + 9.0, 0.16)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(r_sprite, "position:x", orig_x - 4.0, 0.14)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(r_sprite, "position:x", orig_x, 0.14)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_sfx(stream: AudioStream, volume_offset_db: float = -10.0, pitch_variance: float = 0.05) -> void:
	if not stream:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = attack_sfx_volume_db + volume_offset_db
	sfx.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func play_block_knockback() -> void:
	if is_instance_valid(target_player):
		var tween = create_tween()
		var original_x = target_player.global_position.x
		tween.tween_property(target_player, "global_position:x", original_x + 15.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target_player, "global_position:x", original_x, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func play_rooster_attack_anim() -> void:
	var rooster_node = get_tree().current_scene.find_child("Rooster", true, false)
	if not rooster_node:
		rooster_node = get_tree().current_scene.find_child("rooster", true, false)

	if rooster_node:
		var r_sprite: AnimatedSprite2D = rooster_node.find_child("AnimatedSprite2D", true, false)
		if r_sprite and r_sprite.sprite_frames and r_sprite.sprite_frames.has_animation("attack"):
			_play_sfx(rooster_attack_sfx)
			r_sprite.play("attack")
			await r_sprite.animation_finished
			await get_tree().create_timer(0.45).timeout
			if is_instance_valid(r_sprite):
				r_sprite.play("default")

func finish_minigame(success: bool) -> void:
	is_active = false
	visible = false

	if success:
		_restore_previous_bgm()
	else:
		_set_player_fighting_stance(false)
		var battle_player := get_node_or_null("BattleBGMPlayer")
		if battle_player:
			battle_player.stop()
			battle_player.queue_free()
		_play_sfx(game_over_sfx, -10.0, 0.0)

	minigame_completed.emit(success)

func _start_battle_bgm() -> void:
	if not battle_bgm:
		return

	# 1. Simpan BGM dunia sebelumnya lalu hentikan langsung agar tidak bertumpuk
	if MusicManager:
		for child in MusicManager.get_children():
			if child is AudioStreamPlayer and child.playing and child.stream != null:
				_previous_bgm = child.stream
				_previous_bgm_volume = child.volume_db
				child.stop()

	# 2. Hapus player battle lama jika ada, lalu langsung play tanpa fade-in
	var old_player := get_node_or_null("BattleBGMPlayer")
	if old_player:
		old_player.stop()
		old_player.queue_free()

	var bgm_player := AudioStreamPlayer.new()
	bgm_player.name = "BattleBGMPlayer"
	bgm_player.stream = battle_bgm
	bgm_player.volume_db = battle_bgm_volume_db
	add_child(bgm_player)
	bgm_player.play()

func _restore_previous_bgm(fade_duration: float = 1.2) -> void:
	var battle_player := get_node_or_null("BattleBGMPlayer")
	var prev_stream := _previous_bgm
	var prev_vol := _previous_bgm_volume
	_previous_bgm = null

	if battle_player and battle_player.playing:
		# Pindahkan ke MusicManager (autoload) agar tidak ikut terhapus saat ganti scene
		if MusicManager:
			battle_player.reparent(MusicManager)

		var tween := battle_player.create_tween()
		tween.tween_property(battle_player, "volume_db", -40.0, fade_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			if is_instance_valid(battle_player):
				battle_player.stop()
				battle_player.queue_free()
			if prev_stream and MusicManager and MusicManager.has_method("play_world_audio"):
				MusicManager.play_world_audio(null, prev_stream, prev_vol, -12.0)
		)
	else:
		if is_instance_valid(battle_player):
			battle_player.queue_free()
		if prev_stream and MusicManager and MusicManager.has_method("play_world_audio"):
			MusicManager.play_world_audio(null, prev_stream, prev_vol, -12.0)

func _set_player_fighting_stance(active: bool) -> void:
	if not is_instance_valid(target_player):
		target_player = get_tree().current_scene.find_child("Player", true, false)
	if not is_instance_valid(target_player):
		return

	if "is_in_battle" in target_player:
		target_player.is_in_battle = active

	var p_sprite: AnimatedSprite2D = target_player.find_child("AnimatedSprite2D", true, false)
	if p_sprite and p_sprite.sprite_frames:
		if active and p_sprite.sprite_frames.has_animation("fighting"):
			p_sprite.flip_h = false
			p_sprite.play("fighting")
		elif p_sprite.sprite_frames.has_animation("default"):
			p_sprite.play("default")
			

func play_player_hit_effect(with_knockback: bool = true) -> void:
	if not is_instance_valid(target_player):
		target_player = get_tree().current_scene.find_child("Player", true, false)

	if is_instance_valid(target_player):
		var p_sprite: CanvasItem = target_player.find_child("AnimatedSprite2D", true, false)
		if p_sprite:
			var mat := p_sprite.material as ShaderMaterial
			if not mat or not mat.shader:
				var shader := Shader.new()
				shader.code = """
shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, vec3(1.0), flash_amount), tex.a);
}
"""
				mat = ShaderMaterial.new()
				mat.shader = shader
				p_sprite.material = mat

			var orig_x: float = p_sprite.position.x

			# Tween 1: Warna putih solid lalu memudar
			var flash_tween := create_tween()
			mat.set_shader_parameter("flash_amount", 1.0)
			flash_tween.tween_interval(0.20)
			flash_tween.tween_method(
				func(val: float): mat.set_shader_parameter("flash_amount", val),
				1.0, 0.0, 0.25
			)

			# Tween 2 (terpisah): Hentakan mundur lalu langsung balik tanpa nunggu flash selesai
			if with_knockback:
				var move_tween := create_tween()
				move_tween.tween_interval(0.08) # Sedikit jeda hit-stop biar kerasa benturannya
				move_tween.tween_property(p_sprite, "position:x", orig_x + 6.0, 0.07)\
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				move_tween.tween_property(p_sprite, "position:x", orig_x, 0.12)\
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _play_player_combat_anim(anim_name: String) -> void:
	if not is_instance_valid(target_player):
		target_player = get_tree().current_scene.find_child("Player", true, false)
	if not is_instance_valid(target_player):
		return

	var sprite: AnimatedSprite2D = target_player.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		await sprite.animation_finished
		if is_active and sprite.sprite_frames.has_animation("fighting"):
			sprite.play("fighting")
