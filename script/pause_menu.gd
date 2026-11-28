extends CanvasLayer

@export_file("*.tscn") var main_menu_scene: String = "res://scene/Function/main_menu.tscn"
@export var audio_fade_duration: float = 0.4

@export_group("Arrow & Blink Settings")
@export var arrow_scale: float = 2.0
@export var arrow_gap: float = 10.0
@export var blink_interval: float = 0.45

@export_group("SFX Settings")
@export var nav_sfx: AudioStream
@export var confirm_sfx: AudioStream
@export var sfx_volume_db: float = 0.0

@onready var menu_panel: Control = $Control
@onready var resume_button: Button = $Control/Panel/ResumeButton
@onready var main_menu_button: Button = $Control/Panel/MainMenuButton

var excluded_scenes: Array[String] = ["main_menu", "intro"]
var _is_transitioning: bool = false
var _buttons: Array[Button] = []
var _selected_index: int = 0

var arrow_rect: TextureRect
var blink_tween: Tween
var sfx_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_panel.visible = false

	# Buat AudioStreamPlayer khusus SFX (tetap jalan saat game pause)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	sfx_player.volume_db = sfx_volume_db
	add_child(sfx_player)

	# Buat panah pixel 7x7 persis seperti di main_menu.gd
	_create_pixel_arrow()

	# Hilangkan kotak focus/border bawaan Button dan rapikan tombol
	_buttons = [resume_button, main_menu_button]
	var empty_style := StyleBoxEmpty.new()
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.add_theme_stylebox_override("normal", empty_style)
			btn.add_theme_stylebox_override("hover", empty_style)
			btn.add_theme_stylebox_override("pressed", empty_style)
			btn.add_theme_stylebox_override("focus", empty_style)
			btn.add_theme_stylebox_override("disabled", empty_style)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.focus_mode = Control.FOCUS_NONE

	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func _create_pixel_arrow() -> void:
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pattern := [
		"1100000",
		"1111000",
		"1111110",
		"1111111",
		"1111110",
		"1111000",
		"1100000"
	]
	for y in range(7):
		for x in range(7):
			if pattern[y][x] == "1":
				img.set_pixel(x, y, Color.WHITE)

	var pixel_tex := ImageTexture.create_from_image(img)
	arrow_rect = TextureRect.new()
	arrow_rect.texture = pixel_tex
	arrow_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrow_rect.stretch_mode = TextureRect.STRETCH_SCALE

	var final_size := Vector2(round(7.0 * arrow_scale), round(7.0 * arrow_scale))
	arrow_rect.custom_minimum_size = final_size
	arrow_rect.size = final_size
	arrow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_rect.visible = false
	menu_panel.add_child(arrow_rect)

func _input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel"):
		if _is_excluded_scene():
			return
		toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if not menu_panel.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S:
			_select_button(wrapi(_selected_index + 1, 0, _buttons.size()), true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_W:
			_select_button(wrapi(_selected_index - 1, 0, _buttons.size()), true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E or (InputMap.has_action("interact") and event.is_action_pressed("interact")):
			var current_btn := _buttons[_selected_index]
			if is_instance_valid(current_btn):
				current_btn.emit_signal("pressed")
			get_viewport().set_input_as_handled()

func _select_button(idx: int, play_sound: bool = true) -> void:
	if _buttons.is_empty():
		return
	_selected_index = idx
	var target_btn := _buttons[_selected_index]
	if not is_instance_valid(target_btn):
		return

	if play_sound:
		_play_sfx(nav_sfx)

	# Posisikan panah tepat di sebelah kiri teks tombol yang dipilih
	var font := target_btn.get_theme_font("font")
	var font_size := target_btn.get_theme_font_size("font_size")
	var text_width := font.get_string_size(target_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_left_x := target_btn.global_position.x + (target_btn.size.x - text_width) * 0.5
	var center_y := target_btn.global_position.y + (target_btn.size.y - arrow_rect.size.y) * 0.5

	arrow_rect.global_position = Vector2(text_left_x - arrow_rect.size.x - arrow_gap, center_y)
	_start_blink_tween()

func _start_blink_tween() -> void:
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()

	arrow_rect.visible = true
	blink_tween = create_tween().set_loops()
	blink_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	blink_tween.tween_interval(blink_interval)
	blink_tween.tween_callback(func(): arrow_rect.visible = false)
	blink_tween.tween_interval(blink_interval)
	blink_tween.tween_callback(func(): arrow_rect.visible = true)

func _play_confirm_effect(selected_btn: Button) -> void:
	_play_sfx(confirm_sfx)

	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	arrow_rect.visible = true

	# Kedip cepat panah seperti di main_menu.gd
	var confirm_blink := create_tween().set_loops(3)
	confirm_blink.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	confirm_blink.tween_interval(0.05)
	confirm_blink.tween_callback(func(): arrow_rect.visible = false)
	confirm_blink.tween_interval(0.05)
	confirm_blink.tween_callback(func(): arrow_rect.visible = true)

	# Animasi tekan tombol membal ke bawah sedikit
	var orig_pos := selected_btn.position
	var press_tween := create_tween()
	press_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	press_tween.tween_property(selected_btn, "position:y", orig_pos.y + 2.0, 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(selected_btn, "position:y", orig_pos.y, 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await press_tween.finished

func _play_sfx(stream: AudioStream) -> void:
	if stream and is_instance_valid(sfx_player):
		sfx_player.stream = stream
		sfx_player.volume_db = sfx_volume_db
		sfx_player.play()

func _is_excluded_scene() -> bool:
	var current := get_tree().current_scene
	if not is_instance_valid(current):
		return true
	var scene_name := current.scene_file_path.get_file().get_basename().to_lower()
	return scene_name in excluded_scenes

func toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	menu_panel.visible = should_pause

	if should_pause:
		await get_tree().process_frame
		_select_button(0, true)
	else:
		if blink_tween and blink_tween.is_valid():
			blink_tween.kill()
		arrow_rect.visible = false

func _on_resume_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _play_confirm_effect(resume_button)

	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	arrow_rect.visible = false
	get_tree().paused = false
	menu_panel.visible = false
	_is_transitioning = false

func _on_main_menu_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _play_confirm_effect(main_menu_button)

	var has_tweener := _fade_out_all_audio(audio_fade_duration)
	if has_tweener:
		await get_tree().create_timer(audio_fade_duration, true).timeout

	_stop_all_audio()

	if get_node_or_null("/root/DialogueManager") and DialogueManager.has_method("end_dialogue"):
		DialogueManager.end_dialogue()

	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	arrow_rect.visible = false
	get_tree().paused = false
	menu_panel.visible = false

	var transition := get_node_or_null("/root/SceneTransition")
	if transition:
		transition.process_mode = Node.PROCESS_MODE_ALWAYS
		if transition.has_method("change_scene"):
			transition.change_scene(main_menu_scene)
		elif transition.has_method("transition_to"):
			transition.transition_to(main_menu_scene)
		elif transition.has_method("fade_to_scene"):
			transition.fade_to_scene(main_menu_scene)
		else:
			get_tree().change_scene_to_file(main_menu_scene)
	else:
		get_tree().change_scene_to_file(main_menu_scene)

	_is_transitioning = false

func _fade_out_all_audio(duration: float) -> bool:
	var root := get_tree().root
	if not root:
		return false

	var active_players: Array[Node] = []
	for node in root.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
			if node == sfx_player:
				continue
			if node.playing or node.stream_paused:
				active_players.append(node)

	if active_players.is_empty():
		return false

	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for player in active_players:
		tween.tween_property(player, "volume_db", -50.0, duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	return true

func _stop_all_audio() -> void:
	var root := get_tree().root
	if root:
		for node in root.find_children("*", "", true, false):
			if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
				if node == sfx_player:
					continue
				node.stop()
				node.volume_db = 0.0

	var music_mgr := get_node_or_null("/root/MusicManager")
	if music_mgr:
		if music_mgr.has_method("stop_music"):
			music_mgr.stop_music()
		elif music_mgr.has_method("stop"):
			music_mgr.stop()
