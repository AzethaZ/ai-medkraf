extends CanvasLayer

@export var arrow_offset: Vector2 = Vector2(-10, 1)
@export var arrow_scale: float = 1.5
@export var blink_interval: float = 0.28

@export_group("Menu SFX")
@export var select_sfx: AudioStream
@export var confirm_sfx: AudioStream
@export var sfx_volume: float = 0.0

@export_group("Cinematic Transition")
@export var press_flash_color: Color = Color(1.0, 1.0, 1.0, 0.28)
@export var flash_fade_duration: float = 0.45
@export var fade_out_duration: float = 1.35
@export var hold_black_duration: float = 0.35

@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var options_button: Button = $MarginContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $MarginContainer/VBoxContainer/ExitButton
@onready var bgm_player: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")

var menu_buttons: Array[Button] = []
var current_index: int = 0
var arrow_rect: TextureRect
var flash_overlay: ColorRect
var blink_tween: Tween
var is_transitioning: bool = false
var sfx_player: AudioStreamPlayer

func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = sfx_volume
	add_child(sfx_player)

	# Pastikan BGM MainMenu langsung menyala & berulang (loop)
	if bgm_player and bgm_player.stream:
		if not bgm_player.finished.is_connected(_on_bgm_finished):
			bgm_player.finished.connect(_on_bgm_finished)
		if not bgm_player.playing:
			bgm_player.play()

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
	add_child(arrow_rect)

	var empty_style := StyleBoxEmpty.new()
	for btn in [start_button, options_button, exit_button]:
		if btn and btn.visible:
			btn.add_theme_stylebox_override("focus", empty_style)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.focus_mode = Control.FOCUS_NONE
			menu_buttons.append(btn)

	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_quit_button_pressed)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 90
	add_child(flash_layer)

	flash_overlay = ColorRect.new()
	flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_layer.add_child(flash_overlay)

	await get_tree().process_frame
	if menu_buttons.size() > 0:
		_start_blink_tween()
		_select_button(0, false)


func _on_bgm_finished() -> void:
	if not is_transitioning and bgm_player:
		bgm_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if menu_buttons.is_empty() or is_transitioning:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			get_viewport().set_input_as_handled()
			var prev_index := wrapi(current_index - 1, 0, menu_buttons.size())
			_select_button(prev_index, true)

		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			get_viewport().set_input_as_handled()
			var next_index := wrapi(current_index + 1, 0, menu_buttons.size())
			_select_button(next_index, true)

		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			_play_sfx(confirm_sfx)
			menu_buttons[current_index].emit_signal("pressed")


func _select_button(index: int, play_sound: bool = true) -> void:
	current_index = index
	var btn := menu_buttons[current_index]
	if not arrow_rect:
		return

	if play_sound:
		_play_sfx(select_sfx)

	var font := btn.get_theme_font("font")
	var font_size := btn.get_theme_font_size("font_size")
	var text_width := font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_left_x := btn.global_position.x + (btn.size.x * 0.5) - (text_width * 0.5)

	var target_x := text_left_x - arrow_rect.size.x + arrow_offset.x
	var target_y := btn.global_position.y + (btn.size.y * 0.5) - (arrow_rect.size.y * 0.5) + arrow_offset.y
	arrow_rect.global_position = Vector2(target_x, target_y)

	_start_blink_tween()


func _play_sfx(stream: AudioStream) -> void:
	if stream and sfx_player:
		sfx_player.stream = stream
		sfx_player.volume_db = sfx_volume
		sfx_player.play()


func _start_blink_tween() -> void:
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()

	arrow_rect.visible = true
	blink_tween = create_tween().set_loops()
	blink_tween.tween_interval(blink_interval)
	blink_tween.tween_callback(func(): arrow_rect.visible = false)
	blink_tween.tween_interval(blink_interval)
	blink_tween.tween_callback(func(): arrow_rect.visible = true)


func _play_cinematic_transition(selected_btn: Button) -> void:
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	arrow_rect.visible = true

	var confirm_blink := create_tween().set_loops(3)
	confirm_blink.tween_interval(0.11)
	confirm_blink.tween_callback(func(): arrow_rect.visible = false)
	confirm_blink.tween_interval(0.11)
	confirm_blink.tween_callback(func(): arrow_rect.visible = true)

	var orig_pos := selected_btn.position
	var press_tween := create_tween()
	press_tween.tween_property(selected_btn, "position:y", orig_pos.y + 2.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(selected_btn, "position:y", orig_pos.y, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	flash_overlay.color = press_flash_color
	var flash_tween := create_tween()
	flash_tween.tween_property(flash_overlay, "color:a", 0.0, flash_fade_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Turunkan volume BGM perlahan sampai habis saat Start ditekan
	if bgm_player and bgm_player.playing:
		var audio_tween := create_tween()
		audio_tween.tween_property(bgm_player, "volume_db", -50.0, flash_fade_duration + fade_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await flash_tween.finished
	await SceneTransition.fade_out(fade_out_duration)

	if bgm_player:
		bgm_player.stop()

	if hold_black_duration > 0.0:
		await get_tree().create_timer(hold_black_duration).timeout


func _on_start_button_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	await _play_cinematic_transition(start_button)
	get_tree().change_scene_to_file("res://scene/Function/intro_narrative.tscn")


func _on_quit_button_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	await _play_cinematic_transition(exit_button)
	get_tree().quit()
