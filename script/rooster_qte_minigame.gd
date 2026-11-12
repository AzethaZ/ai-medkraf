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

var default_bar_pos_x: float = 0.0
var full_bar_width: float = 180.0


func _ready() -> void:
	visible = false
	is_active = false
	load_textures()
	if background_bar:
		default_bar_pos_x = background_bar.position.x
		full_bar_width = background_bar.size.x if background_bar.size.x > 0 else 180.0


func load_textures() -> void:
	key_textures = {
		"w": load("res://assets/ui/arrow_up.png") if ResourceLoader.exists("res://assets/ui/arrow_up.png") else null,
		"a": load("res://assets/ui/arrow_left.png") if ResourceLoader.exists("res://assets/ui/arrow_left.png") else null,
		"s": load("res://assets/ui/arrow_down.png") if ResourceLoader.exists("res://assets/ui/arrow_down.png") else null,
		"d": load("res://assets/ui/arrow_right.png") if ResourceLoader.exists("res://assets/ui/arrow_right.png") else null,
		"interact": load("res://assets/ui/button_e.png") if ResourceLoader.exists("res://assets/ui/button_e.png") else null
	}


func start_minigame(player_node: Node2D = null) -> void:
	target_player = player_node
	score_count = 0
	strike_count = 0
	visible = true
	is_active = true
	can_proceed_next = true
	
	if red_bar: 
		red_bar.scale.x = 1.0
		red_bar.position.x = default_bar_pos_x
	if background_bar: 
		background_bar.scale.x = 1.0
		background_bar.position.x = default_bar_pos_x

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
	current_sequence.clear()
	for i in range(sequence_length):
		current_sequence.append(possible_keys.pick_random())


func generate_spam_display() -> void:
	if not sequence_container:
		return

	for child in sequence_container.get_children():
		child.queue_free()

	var label = Label.new()
	label.text = "SPAM E (BLOCK)!"
	label.custom_minimum_size = Vector2(100, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(1.0, 0.6, 0.2, 1.0)
	sequence_container.add_child(label)


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
				rect.modulate = Color(0.2, 1.0, 0.2, 1.0)
			elif i == current_input_index:
				rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				rect.modulate = Color(0.4, 0.4, 0.4, 0.5)

			sequence_container.add_child(rect)
		else:
			var label = Label.new()
			var fallback_map = {"w": "W", "a": "A", "s": "S", "d": "D", "interact": "[E]"}
			label.text = fallback_map.get(key_code, "[?]")
			label.custom_minimum_size = Vector2(28, 28)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			if i < current_input_index:
				label.modulate = Color(0.2, 1.0, 0.2, 1.0)
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
	var target_node = panel_container if panel_container else self
	var tween = create_tween()
	tween.tween_property(target_node, "modulate", Color(2.0, 0.4, 0.4), 0.08)
	tween.tween_property(target_node, "modulate", Color.WHITE, 0.12)


func _input(event: InputEvent) -> void:
	if not is_active or not visible or not can_proceed_next:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var keycode_val = event.keycode if event.keycode != 0 else event.physical_keycode

		if is_spam_phase:
			if keycode_val == KEY_E or event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				
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

			if pressed_key_name == target_key:
				current_input_index += 1
				update_sequence_display()

				if current_input_index >= current_sequence.size():
					can_proceed_next = false
					handle_attack_success()
			else:
				handle_attack_fail()


func handle_block_success() -> void:
	play_block_knockback()
	score_count += 1

	var transition_timer = get_tree().create_timer(1.0)
	transition_timer.timeout.connect(func():
		next_round()
	)


func handle_attack_success() -> void:
	play_chicken_hit_effect()
	score_count += 1
	rooster_damaged.emit()

	var transition_timer = get_tree().create_timer(1.0)
	transition_timer.timeout.connect(func():
		next_round()
	)


func play_chicken_hit_effect() -> void:
	var rooster_node = get_tree().current_scene.find_child("Rooster", true, false)
	if not rooster_node:
		rooster_node = get_tree().current_scene.find_child("rooster", true, false)
	
	if rooster_node:
		var r_sprite = rooster_node.find_child("AnimatedSprite2D", true, false)
		if r_sprite:
			var tween = create_tween()
			tween.tween_property(r_sprite, "modulate", Color(1.0, 0.3, 0.3), 0.08)
			tween.tween_property(r_sprite, "position:x", r_sprite.position.x - 10.0, 0.05)
			tween.tween_property(r_sprite, "position:x", r_sprite.position.x + 10.0, 0.05)
			tween.tween_property(r_sprite, "modulate", Color.WHITE, 0.15)


func play_block_knockback() -> void:
	if is_instance_valid(target_player):
		var tween = create_tween()
		var original_x = target_player.global_position.x
		tween.tween_property(target_player, "global_position:x", original_x + 15.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target_player, "global_position:x", original_x, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func finish_minigame(success: bool) -> void:
	is_active = false
	visible = false
	minigame_completed.emit(success)
