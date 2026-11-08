extends CanvasLayer

signal dialogue_finished

@onready var box_anchor: Control = $BoxAnchor if has_node("BoxAnchor") else null
@onready var dialogue_box: PanelContainer = $BoxAnchor/DialogueBox if has_node("BoxAnchor/DialogueBox") else null
@onready var message_label: Label = $BoxAnchor/DialogueBox/VBoxContainer/MessageLabel if has_node("BoxAnchor/DialogueBox/VBoxContainer/MessageLabel") else null
@onready var next_indicator: TextureRect = $BoxAnchor/DialogueBox/NextIndicator if has_node("BoxAnchor/DialogueBox/NextIndicator") else null

# --- REFERENSI AUDIO ---
@onready var type_sound: AudioStreamPlayer = $TypeSound if has_node("TypeSound") else null

var dialogue_lines: Array = []
var current_line_index: int = 0
var is_active: bool = false
var is_just_started: bool = false
var text_tween: Tween
var indicator_tween: Tween
var box_tween: Tween

var target_speaker: Node2D = null
var current_npc_node: Node2D = null

# Flag internal penanda proses pengetikan
var is_typing: bool = false

func _ready() -> void:
	visible = false
	if next_indicator:
		next_indicator.visible = false

func _process(_delta: float) -> void:
	if not is_active:
		return

	if is_instance_valid(target_speaker) and box_anchor:
		update_anchor_position()

func start_dialogue(lines: Array, npc_node: Node2D = null) -> void:
	if lines.is_empty():
		return

	current_npc_node = npc_node
	dialogue_lines = lines
	current_line_index = 0
	is_active = true
	visible = true
	is_just_started = true

	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		if player.has_method("set_dialogue_state"):
			player.set_dialogue_state(true)
		else:
			player.set_physics_process(false)
			player.set_process(false)

	show_current_line()

	await get_tree().process_frame
	is_just_started = false

func show_current_line() -> void:
	stop_indicator_anim()
	if next_indicator:
		next_indicator.visible = false

	if current_line_index >= dialogue_lines.size():
		end_dialogue()
		return

	# Ambil data dialog saat ini
	var current_item = dialogue_lines[current_line_index]
	var message_text: String = ""
	
	# Deteksi penutur (MC atau NPC)
	if current_item is Dictionary:
		message_text = current_item.get("text", "")
		var speaker_type = current_item.get("speaker", "npc")
		
		if speaker_type == "mc":
			var player = get_tree().current_scene.find_child("Player", true, false)
			target_speaker = player
		else:
			target_speaker = current_npc_node
	else:
		message_text = str(current_item)
		target_speaker = current_npc_node

	if message_label:
		message_label.text = message_text
		message_label.visible_characters = 0

		if dialogue_box:
			dialogue_box.reset_size()
			update_anchor_position()

			dialogue_box.pivot_offset = Vector2(dialogue_box.size.x / 2.0, dialogue_box.size.y)
			dialogue_box.position = Vector2(-dialogue_box.size.x / 2.0, -dialogue_box.size.y)

			if box_tween and box_tween.is_valid():
				box_tween.kill()

			dialogue_box.scale = Vector2(0.7, 0.3)
			box_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			box_tween.tween_property(dialogue_box, "scale", Vector2(1.0, 1.0), 0.2)

		# --- ANIMASI KETIK PER KATA + SFX TYPE SOUND (RANDOM PITCH) ---
		is_typing = true
		var total_chars = message_text.length()
		
		for i in range(1, total_chars + 1):
			if not is_typing:
				break
				
			message_label.visible_characters = i
			
			var is_first_char = (i == 1)
			var is_new_word = (i > 1 and message_text[i - 2] == " " and message_text[i - 1] != " ")
			
			if (is_first_char or is_new_word) and message_text[i - 1] != "\n":
				if type_sound:
					type_sound.pitch_scale = randf_range(0.55, 1.10)
					type_sound.play()
				
			await get_tree().create_timer(0.020).timeout
			
		_on_text_typing_finished()

func _on_text_typing_finished() -> void:
	is_typing = false
	if message_label:
		message_label.visible_characters = -1

	if next_indicator:
		next_indicator.visible = true
		start_indicator_anim()

func start_indicator_anim() -> void:
	if not next_indicator:
		return

	stop_indicator_anim()
	next_indicator.visible = true

	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_property(next_indicator, "visible", false, 0.01).set_delay(0.5)
	indicator_tween.tween_property(next_indicator, "visible", true, 0.01).set_delay(0.5)

func stop_indicator_anim() -> void:
	if indicator_tween and indicator_tween.is_valid():
		indicator_tween.kill()
	if next_indicator:
		next_indicator.visible = false

func advance_dialogue() -> void:
	current_line_index += 1
	show_current_line()

func end_dialogue() -> void:
	is_active = false
	is_typing = false
	stop_indicator_anim()

	if dialogue_box:
		if box_tween and box_tween.is_valid():
			box_tween.kill()
		box_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		box_tween.tween_property(dialogue_box, "scale", Vector2(0.7, 0.3), 0.08)
		await box_tween.finished

	visible = false

	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		if player.has_method("set_dialogue_state"):
			player.set_dialogue_state(false)
		else:
			player.set_physics_process(true)
			player.set_process(true)

	dialogue_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or is_just_started:
		return

	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()

		if is_typing:
			is_typing = false
			_on_text_typing_finished()
		else:
			advance_dialogue()

func update_anchor_position() -> void:
	if not is_instance_valid(target_speaker) or not box_anchor:
		return
	
	# 1. Jika speaker memiliki node DialoguePivot (seperti di player.tscn)
	if target_speaker.has_node("DialoguePivot"):
		var pivot = target_speaker.get_node("DialoguePivot")
		
		# Ambil koordinat layar (Canvas) langsung dari node DialoguePivot
		var pivot_screen_pos = pivot.get_global_transform_with_canvas().origin
		
		# Jika MC sedang bicara dengan NPC, berikan ekstra offset Y (-25px) agar tidak menutupi NPC
		var player = get_tree().current_scene.find_child("Player", true, false)
		var extra_y: float = 0.0
		if target_speaker == player and current_npc_node != null:
			extra_y = -25.0
			
		box_anchor.global_position = pivot_screen_pos + Vector2(0, extra_y)
		
	# 2. Fallback jika tidak ada DialoguePivot (Kalkulasi dari Sprite/Origin)
	else:
		var speaker_screen_pos = target_speaker.get_global_transform_with_canvas().origin
		var y_offset = get_speaker_offset(target_speaker)
		box_anchor.global_position = speaker_screen_pos + Vector2(0, y_offset)

func get_speaker_offset(speaker: Node2D) -> float:
	if not is_instance_valid(speaker):
		return -36.0

	# Digunakan khusus jika speaker TIDAK memiliki node DialoguePivot
	var sprite = speaker.find_child("*Sprite*", true, false)
	if sprite:
		if sprite is AnimatedSprite2D and sprite.sprite_frames:
			var current_anim = sprite.animation
			var texture = sprite.sprite_frames.get_frame_texture(current_anim, sprite.frame)
			if texture:
				var half_height = (texture.get_height() * sprite.scale.y) * 0.5
				return -(half_height + 4.0)
		elif sprite is Sprite2D and sprite.texture:
			var half_height = (sprite.texture.get_height() * sprite.scale.y) * 0.5
			return -(half_height + 4.0)

	return -36.0
