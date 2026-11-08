extends Control

signal minigame_completed(success: bool)

# Path aset gambar
var key_textures: Dictionary = {}

var possible_keys: Array[String] = ["w", "a", "s", "d", "interact"]
var current_sequence: Array[String] = []
var current_input_index: int = 0
var sequence_length: int = 4

var score_count: int = 0
var target_score: int = 3

var time_limit: float = 3.0
var current_timer: float = 0.0
var is_active: bool = false
var target_player: Node2D = null

@onready var sequence_container: HBoxContainer = $PanelContainer/VBoxContainer/SequenceContainer if has_node("PanelContainer/VBoxContainer/SequenceContainer") else null
@onready var timer_bar: ProgressBar = $PanelContainer/VBoxContainer/TimerBar if has_node("PanelContainer/VBoxContainer/TimerBar") else null

func _ready() -> void:
	visible = false
	is_active = false
	load_textures()

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
	visible = true
	is_active = true
	next_round()

func next_round() -> void:
	if score_count >= target_score:
		finish_minigame(true)
		return

	current_input_index = 0
	current_timer = time_limit
	generate_random_sequence()
	update_sequence_display()

	if timer_bar:
		timer_bar.max_value = time_limit
		timer_bar.value = time_limit

func generate_random_sequence() -> void:
	current_sequence.clear()
	for i in range(sequence_length):
		current_sequence.append(possible_keys.pick_random())

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

			rect.custom_minimum_size = Vector2(20, 20)
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
			var fallback_map = {"w":"W", "a":"A", "s":"S", "d":"D", "interact":"[E]"}
			label.text = fallback_map.get(key_code, "[?]")
			label.custom_minimum_size = Vector2(20, 20)
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

	if is_instance_valid(target_player):
		var player_screen_pos = target_player.get_global_transform_with_canvas().origin
		global_position = player_screen_pos + Vector2(-40.0, -90.0)

	current_timer -= delta
	if timer_bar:
		timer_bar.value = current_timer

	if current_timer <= 0:
		finish_minigame(false)

func _input(event: InputEvent) -> void:
	if not is_active or not visible:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if current_input_index >= current_sequence.size():
			return

		var target_key = current_sequence[current_input_index]
		var pressed_key_name: String = ""

		var keycode = event.keycode
		if keycode == 0:
			keycode = event.physical_keycode

		match keycode:
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
					score_count += 1
					next_round()
			else:
				finish_minigame(false)

func finish_minigame(success: bool) -> void:
	is_active = false
	visible = false
	minigame_completed.emit(success)
