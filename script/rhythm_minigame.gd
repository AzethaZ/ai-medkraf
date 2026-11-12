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

enum State { INACTIVE, SHRINKING, RESULT }
var current_state: State = State.INACTIVE

# Data Pola Ritme
var active_offsets: Array[Vector2] = []
var active_beat_names: Array[String] = []

var shrink_duration: float = 0.9
var window_duration: float = 0.4
var elapsed_time: float = 0.0

var current_round: int = 1
var total_rounds: int = 4

var success_tween: Tween = null
var fail_tween: Tween = null


func _ready() -> void:
	visible = false
	set_process(false)

	if approach_circle:
		approach_circle.pivot_offset = approach_circle.size / 2.0
	if base_circle:
		base_circle.pivot_offset = base_circle.size / 2.0
	if beat_label:
		beat_label.pivot_offset = beat_label.size / 2.0

	if success_particles:
		success_particles.emitting = false
		success_particles.one_shot = true


# Panggil fungsi ini untuk memulai minigame dengan memilih pola (1, 2, atau 3)
func start_minigame(pattern_type: int = 1) -> void:
	visible = true
	current_round = 1
	_setup_pattern(pattern_type)
	start_new_round()


func _setup_pattern(type: int) -> void:
	match type:
		1: # Pola 1: Kotak (4 Ketukan, Normal)
			total_rounds = 4
			shrink_duration = 0.9
			active_offsets = [
				Vector2(-120, -90),
				Vector2(-120, -20),
				Vector2(120, -90),
				Vector2(120, -20)
			]
			active_beat_names = ["Tu...", "Wa...", "Ga...", "Pat!"]

		2: # Pola 2: Segitiga (3 Ketukan, Lebih Lambat)
			total_rounds = 3
			shrink_duration = 1.3 # Ketukan diset lebih lambat
			active_offsets = [
				Vector2(0, -110),   # Atas
				Vector2(-110, -20), # Kiri Bawah
				Vector2(110, -20)   # Kanan Bawah
			]
			active_beat_names = ["Satu...", "Dua...", "Tiga!"]

		3: # Pola 3: Polygon / Pentagon (5 Ketukan, Normal)
			total_rounds = 5
			shrink_duration = 0.9
			active_offsets = [
				Vector2(0, -110),   # Atas
				Vector2(110, -70),  # Kanan Atas
				Vector2(80, -10),   # Kanan Bawah
				Vector2(-80, -10),  # Kiri Bawah
				Vector2(-110, -70)  # Kiri Atas
			]
			active_beat_names = ["Tu...", "Wa...", "Ga...", "Pat...", "Hop!"]

		_:
			_setup_pattern(1) # Default ke pola 1


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

	if instruction_label:
		var current_name = active_beat_names[current_round - 1] if (current_round - 1) < active_beat_names.size() else ""
		instruction_label.text = current_name

	elapsed_time = 0.0
	current_state = State.SHRINKING
	set_process(true)


func _process(delta: float) -> void:
	if current_state != State.SHRINKING:
		return

	elapsed_time += delta

	var progress: float = clamp(elapsed_time / shrink_duration, 0.0, 1.0)
	var current_scale: float = lerp(3.0, 1.0, progress)
	approach_circle.scale = Vector2(current_scale, current_scale)

	if elapsed_time > (shrink_duration + window_duration):
		handle_fail()


func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.SHRINKING:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.is_pressed() and not event.is_echo()):
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
		# Pitch menyesuaikan jumlah total_rounds
		var pitch_step = 0.6 / float(max(1, total_rounds - 1))
		success_sound.pitch_scale = 0.8 + ((current_round - 1) * pitch_step)
		success_sound.play()

	_trigger_particle_burst()

	if current_round < total_rounds:
		current_round += 1
		start_new_round()
	else:
		current_state = State.INACTIVE
		visible = false
		minigame_completed.emit(true)


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
	await fail_tween.finished

	current_state = State.INACTIVE
	visible = false
	minigame_completed.emit(false)


func _trigger_particle_burst() -> void:
	if success_particles:
		success_particles.global_position = qte_circle.global_position + (qte_circle.size / 2.0)
		success_particles.restart()
		success_particles.emitting = true
