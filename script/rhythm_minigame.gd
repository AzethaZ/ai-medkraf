extends CanvasLayer

signal minigame_completed(success: bool)

@onready var qte_circle: Control = $QTECircle
@onready var base_circle: Control = $QTECircle/BaseCircle
@onready var approach_circle: Control = $QTECircle/ApproachCircle
@onready var beat_label: Label = $QTECircle/Label
@onready var instruction_label: Label = $InstructionLabel

enum State { INACTIVE, SHRINKING, RESULT }
var current_state: State = State.INACTIVE

# Pengaturan Timing (Detik)
var shrink_duration: float = 0.9     # Waktu lingkaran mengecil ke skala 1.0 (BaseCircle)
var window_duration: float = 0.5    # Toleransi waktu setelah menyatu di tengah
var elapsed_time: float = 0.0

var current_round: int = 1
# Cari baris ini di rhythm_minigame.gd lalu ubah nilainya:
var total_rounds: int = 3

var success_tween: Tween = null
var fail_tween: Tween = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	
	if approach_circle:
		approach_circle.pivot_offset = approach_circle.size / 2.0
	if base_circle:
		base_circle.pivot_offset = base_circle.size / 2.0

func start_minigame() -> void:
	visible = true
	current_round = 1
	start_new_round()

func start_new_round() -> void:
	if success_tween and success_tween.is_running(): 
		success_tween.kill()
	if fail_tween and fail_tween.is_running():
		fail_tween.kill()

	qte_circle.modulate = Color.WHITE
	qte_circle.scale = Vector2(1.0, 1.0)
	approach_circle.scale = Vector2(3.0, 3.0)

	var viewport_size = get_viewport().get_visible_rect().size
	if qte_circle:
		qte_circle.position = (viewport_size / 2.0) - (qte_circle.size / 2.0)

	beat_label.text = "E"
	if instruction_label:
		instruction_label.text = "Tekan E pas lingkaran pas di tengah! (" + str(current_round) + "/" + str(total_rounds) + ")"

	elapsed_time = 0.0
	current_state = State.SHRINKING
	set_process(true)

func _process(delta: float) -> void:
	if current_state != State.SHRINKING:
		return

	elapsed_time += delta

	# 1. Animasi Lingkaran Mengecil secara Kontinu
	var progress: float = clamp(elapsed_time / shrink_duration, 0.0, 1.0)
	var current_scale: float = lerp(3.0, 1.0, progress)
	approach_circle.scale = Vector2(current_scale, current_scale)

	# 2. Jika Kelewat Tanpa Ditekan -> Langsung Gagal!
	if elapsed_time > (shrink_duration + window_duration):
		handle_fail()

func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.SHRINKING:
		return

	# Deteksi penekanan tombol E / Interact / Space
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		# Kunci input di frame ini agar tidak diproses berulang
		get_viewport().set_input_as_handled()

		# Waktu area sukses (mulai dari lingkaran mendekati BaseCircle sampai window habis)
		var min_success_time: float = shrink_duration - 0.35
		var max_success_time: float = shrink_duration + window_duration

		# Jika ditekan di dalam window -> SUKSES
		if elapsed_time >= min_success_time and elapsed_time <= max_success_time:
			handle_success()
		else:
			# Ditekan terlalu cepat (kapan pun itu) -> LANGSUNG GAGAL!
			handle_fail()

func handle_success() -> void:
	current_state = State.RESULT
	set_process(false)
	
	beat_label.text = "PAS!"
	play_success_effect()
	
	await move_player_left()

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
	
	# Paksa tampilan visual berubah jadi merah & GAGAL seketika
	beat_label.text = "GAGAL!"
	qte_circle.modulate = Color(1.0, 0.2, 0.2)
	
	if fail_tween and fail_tween.is_running():
		fail_tween.kill()

	# Tampilkan pesan GAGAL selama 0.8 detik secara pasti
	fail_tween = create_tween()
	fail_tween.tween_interval(0.8)
	await fail_tween.finished
	
	current_state = State.INACTIVE
	visible = false
	minigame_completed.emit(false)

func move_player_left() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not player:
		return

	var animated_sprite = player.find_child("AnimatedSprite2D", true, false)
	if animated_sprite:
		animated_sprite.flip_h = true
		if animated_sprite.sprite_frames.has_animation("walk"):
			animated_sprite.play("walk")

	var step_distance: float = 45.0
	var total_steps: int = 3
	var step_tween = create_tween()

	for i in range(total_steps):
		var target_x = player.position.x - step_distance
		step_tween.tween_property(player, "position:x", target_x, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		step_tween.tween_interval(0.06)

	await step_tween.finished

	if animated_sprite and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")

func play_success_effect() -> void:
	if success_tween and success_tween.is_running(): 
		success_tween.kill()

	success_tween = create_tween().set_parallel(true)
	qte_circle.pivot_offset = qte_circle.size / 2.0
	success_tween.tween_property(qte_circle, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	success_tween.tween_property(qte_circle, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	qte_circle.modulate = Color(0.3, 1.0, 0.4)
	success_tween.tween_property(qte_circle, "modulate", Color.WHITE, 0.4).set_delay(0.3)
