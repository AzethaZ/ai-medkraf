extends Node2D

signal minigame_completed(success: bool)

@onready var qte_circle: Control = $QTECircle
@onready var base_circle: Control = $QTECircle/BaseCircle
@onready var approach_circle: Control = $QTECircle/ApproachCircle
@onready var beat_label: Label = $QTECircle/Label
@onready var instruction_label: Label = $InstructionLabel if has_node("InstructionLabel") else null
@onready var success_sound: AudioStreamPlayer = $SuccessSound if has_node("SuccessSound") else null
@onready var fail_sound: AudioStreamPlayer = $FailSound if has_node("FailSound") else null
@onready var success_particles: GPUParticles2D = $SuccessParticles if has_node("SuccessParticles") else null

# Referensi ke DialogueBox untuk teks hitungan
@onready var dialogue_box: Control = $BoxAnchor/DialogueBox if has_node("BoxAnchor/DialogueBox") else null
@onready var message_label: Label = $BoxAnchor/DialogueBox/VBoxContainer/MessageLabel if has_node("BoxAnchor/DialogueBox/VBoxContainer/MessageLabel") else null
@onready var fade_rect: ColorRect = find_child("ColorRect", true, false)
# Di bagian atas (sekitar baris 12, di bawah fail_sound):
@onready var complete_sound: AudioStreamPlayer = $CompleteSound if has_node("CompleteSound") else null
@onready var bg_layer: CanvasLayer = $CanvasLayer2 if has_node("CanvasLayer2") else null
@onready var back_rect: ColorRect = $CanvasLayer2/back if has_node("CanvasLayer2/back") else null

var target_back_alpha: float = 0.6

enum State { INACTIVE, SHRINKING, RESULT }
var current_state: State = State.INACTIVE

# Data Pola Ritmik
var active_offsets: Array[Vector2] = []
var active_beat_names: Array[String] = []

var shrink_duration: float = 0.9
var window_duration: float = 0.4
var elapsed_time: float = 0.0

var current_round: int = 1
var total_rounds: int = 4

var success_tween: Tween = null
var fail_tween: Tween = null
var dialogue_tween: Tween = null

func _ready() -> void:
	if back_rect:
		target_back_alpha = back_rect.color.a
		back_rect.color.a = 0.0
	if bg_layer:
		bg_layer.visible = false
	if fade_rect:
		fade_rect.visible = false
		fade_rect.color = Color(0, 0, 0, 0)
	visible = false
	if dialogue_box:
		dialogue_box.visible = false
	
	# Sembunyikan InstructionLabel lama agar tidak muncul di badan karakter
	if instruction_label:
		instruction_label.visible = false

	if approach_circle:
		approach_circle.pivot_offset = approach_circle.size / 2.0
	if base_circle:
		base_circle.pivot_offset = base_circle.size / 2.0
	if beat_label:
		beat_label.pivot_offset = beat_label.size / 2.0

	if success_particles:
		success_particles.emitting = false
		success_particles.one_shot = true

func start_minigame(pattern_type: int = 1) -> void:
	visible = true

	# Munculkan CanvasLayer2 dengan efek fade-in halus
	if bg_layer:
		bg_layer.visible = true
	if back_rect:
		back_rect.color.a = 0.0
		var bg_fade_in := create_tween()
		bg_fade_in.tween_property(back_rect, "color:a", target_back_alpha, 0.25).set_trans(Tween.TRANS_SINE)

	if dialogue_box:
		dialogue_box.visible = true
	current_round = 1
	_setup_pattern(pattern_type)
	start_new_round()
	visible = true

func _setup_pattern(type: int) -> void:
	match type:
		1: # Pola 1: Kotak (4 Ketukan)
			total_rounds = 4
			shrink_duration = 0.9
			active_offsets = [
				Vector2(-90, -130), # Kiri Atas
				Vector2(90, -130),  # Kanan Atas
				Vector2(90, -60),   # Kanan Bawah
				Vector2(-90, -60)   # Kiri Bawah
			]
			active_beat_names = ["Tu...", "Wa...", "Ga...", "Pat!"]
		2: # Pola 2: Segitiga (3 Ketukan)
			total_rounds = 3
			shrink_duration = 1.3
			active_offsets = [
				Vector2(0, -140),   # Puncak Atas
				Vector2(90, -60),   # Kanan Bawah
				Vector2(-90, -60)   # Kiri Bawah
			]
			active_beat_names = ["Satu...", "Dua...", "Tiga!"]
		3: # Pola 3: Pentagon / Persegi Lima (5 Ketukan)
			total_rounds = 5
			shrink_duration = 0.9
			active_offsets = [
				Vector2(0, -150),   # Puncak Atas
				Vector2(90, -110),  # Kanan Atas
				Vector2(60, -60),   # Kanan Bawah
				Vector2(-60, -60),  # Kiri Bawah
				Vector2(-90, -110)  # Kiri Atas
			]
			active_beat_names = ["Tu...", "Wa...", "Ga...", "Pat...", "Hap!"]
		_:
			_setup_pattern(1)

func start_new_round() -> void:
	if success_tween and success_tween.is_running():
		success_tween.kill()
	if fail_tween and fail_tween.is_running():
		fail_tween.kill()

	qte_circle.modulate = Color.WHITE
	qte_circle.scale = Vector2(1.0, 1.0)
	approach_circle.scale = Vector2(3.0, 3.0)

	var offset_index = current_round - 1
	if offset_index < active_offsets.size():
		qte_circle.position = active_offsets[offset_index]

	beat_label.text = str(current_round)
	beat_label.scale = Vector2(1.0, 1.0)
	beat_label.add_theme_font_size_override("font_size", 18)

	# Tampilkan teks hitungan hanya di DialogueBox dengan efek Tween Pop-Up
	if dialogue_box and message_label:
		dialogue_box.visible = true
		if current_round - 1 < active_beat_names.size():
			message_label.text = active_beat_names[current_round - 1]
		
		if dialogue_tween and dialogue_tween.is_running():
			dialogue_tween.kill()
		
		dialogue_box.pivot_offset = dialogue_box.size / 2.0
		dialogue_box.scale = Vector2(0.7, 0.7)
		dialogue_tween = create_tween()
		dialogue_tween.tween_property(dialogue_box, "scale", Vector2(1.0, 1.0), 0.2)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

	elapsed_time = 0.0
	current_state = State.SHRINKING
	set_process(true)

func _process(delta: float) -> void:
	if current_state != State.SHRINKING:
		return

	elapsed_time += delta

	var progress: float = clamp(elapsed_time / shrink_duration, 0.0, 1.0)
	var current_scale: float = lerp(3.6, 1.0, progress)
	approach_circle.scale = Vector2(current_scale, current_scale)

	if elapsed_time > (shrink_duration + window_duration):
		handle_fail()

func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.SHRINKING:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo):
		get_viewport().set_input_as_handled()

		var min_success_time: float = shrink_duration - 0.35
		var max_success_time: float = shrink_duration + window_duration

		if elapsed_time >= min_success_time and elapsed_time <= max_success_time:
			handle_success()
		else:
			handle_fail()

func handle_success() -> void:
	current_state = State.RESULT
	set_process(false)

	if success_sound and success_sound.stream:
		var pitch_step = 0.6 / float(max(1, total_rounds - 1))
		success_sound.pitch_scale = 0.8 + ((current_round - 1) * pitch_step)
		success_sound.play()

	trigger_particle_burst()

	if current_round < total_rounds:
		current_round += 1
		start_new_round()
	else:
		current_state = State.INACTIVE
		if dialogue_box:
			dialogue_box.visible = false
		if qte_circle:
			qte_circle.visible = false

		# Putar SFX berhasil khusus saat fade dimulai
		if complete_sound and complete_sound.stream:
			complete_sound.play()

		# 1. Tween fade layar menjadi gelap penuh (0.35 detik)
		if fade_rect:
			fade_rect.visible = true
			fade_rect.color.a = 0.0
			var fade_in := create_tween()
			fade_in.tween_property(fade_rect, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
			await fade_in.finished

		# 2. Munculkan anak ayam & tutup background minigame saat layar tertutup penuh
		if bg_layer:
			bg_layer.visible = false
		if back_rect:
			back_rect.color.a = 0.0
		minigame_completed.emit(true)
		await get_tree().create_timer(0.2).timeout

		# 3. Tween fade layar kembali terang (0.35 detik)
		if fade_rect:
			var fade_out := create_tween()
			fade_out.tween_property(fade_rect, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
			await fade_out.finished
			fade_rect.visible = false

		if qte_circle:
			qte_circle.visible = true
		visible = false

func handle_fail() -> void:
	current_state = State.RESULT
	set_process(false)

	if fail_sound and fail_sound.stream:
		fail_sound.pitch_scale = 1.0
		fail_sound.play()

	beat_label.text = "X"
	qte_circle.modulate = Color(1.0, 0.2, 0.2)

	if fail_tween and fail_tween.is_running():
		fail_tween.kill()

	fail_tween = create_tween()
	fail_tween.tween_interval(0.8)
	fail_tween.finished.connect(func():
		current_state = State.INACTIVE
		visible = false
		if bg_layer:
			bg_layer.visible = false
		if back_rect:
			back_rect.color.a = 0.0
		if dialogue_box:
			dialogue_box.visible = false
		minigame_completed.emit(false)
	)
	

func trigger_particle_burst() -> void:
	if success_particles:
		success_particles.global_position = qte_circle.global_position + (qte_circle.size / 2.0)
		success_particles.restart()
		success_particles.emitting = true
