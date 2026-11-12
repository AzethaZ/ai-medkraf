extends Node2D

# --- REFERENSI NODE ---
@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

@onready var interact_kiri: Area2D = find_child("InteractKiri", true, false)
@onready var interact_kanan: Area2D = find_child("InteractKanan", true, false)
@onready var area_exit: Area2D = find_child("AreaExit", true, false)

# --- EXPORT VARIABLES ---
@export var bgm_stream: AudioStream
@export var ambience_stream: AudioStream

# --- VARIABEL STATE ---
var interacted_count: int = 0
const TOTAL_REQUIRED: int = 2
var cutscene_triggered: bool = false


func _ready() -> void:
	# 1. Aktifkan mode pincang untuk Danum
	if player and player.has_method("set_limping_mode"):
		player.set_limping_mode(true)

	# 2. Nonaktifkan AreaExit agar pemain tidak bisa keluar map dulu
	if area_exit:
		area_exit.monitoring = false

	# 3. Setup Kamera & Limit Kiri-Kanan (-500 sampai 500)
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()
		camera_2d.limit_left = -450
		camera_2d.limit_right = 430

	# 4. Hubungkan signal dari 2 objek interactable
	if interact_kiri and interact_kiri.has_signal("interacted"):
		interact_kiri.interacted.connect(_on_objek_interacted)
	if interact_kanan and interact_kanan.has_signal("interacted"):
		interact_kanan.interacted.connect(_on_objek_interacted)

	# 5. AUDIO SEAMLESS: Hanya putar/update audio jika belum berputar dari cutscene sebelumnya
	if MusicManager:
		# Cek apakah MusicManager sudah memutar audio. Jika perlu update BGM baru tanpa fade in:
		if MusicManager.has_method("play_world_audio"):
			var bgm_track = bgm_stream if bgm_stream else load("res://assets/audio/kebakaran_music2.mp3")
			var ambience_track = ambience_stream if ambience_stream else load("res://assets/audio/kebakaran_ambience.mp3")
			
			# Memanggil play_world_audio secara langsung tanpa fade-in
			MusicManager.play_world_audio(ambience_track, bgm_track, -12.0, 0.0)

	# 6. Fade In layar masuk ke scene (Visual saja)
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 7. Pemain langsung bisa bebas berjalan
	if player and player.has_method("enable_movement"):
		player.enable_movement()

	# 8. Memunculkan dialog awal
	play_initial_dialogue()


func _exit_tree() -> void:
	if is_instance_valid(player) and player.has_method("set_limping_mode"):
		player.set_limping_mode(false)


func play_initial_dialogue() -> void:
	var text = "Uhkh... Hutan... terbakar?! Aku harus keluar dari sini!"
	trigger_dialogue_manager(text)


func _on_objek_interacted() -> void:
	interacted_count += 1
	print("Interaksi berhasil: ", interacted_count, "/", TOTAL_REQUIRED)

	play_interaction_dialogue(interacted_count)

	if interacted_count >= TOTAL_REQUIRED and not cutscene_triggered:
		cutscene_triggered = true
		start_cutscene_timer()


func play_interaction_dialogue(step: int) -> void:
	var text: String = ""
	if step == 1:
		text = "Tolong! Ada orang di sini?! Api semakin membesar!"
	elif step == 2:
		text = "Nafasku... terengah-engah... aku tidak tahan lagi..."

	if text != "":
		trigger_dialogue_manager(text)


func trigger_dialogue_manager(text: String) -> void:
	if DialogueManager:
		if DialogueManager.has_method("start_dialogue"):
			DialogueManager.start_dialogue([text], player)
		elif DialogueManager.has_method("show_dialogue_text"):
			DialogueManager.show_dialogue_text(text, player)
		elif DialogueManager.has_method("show_dialogue"):
			DialogueManager.show_dialogue(text, player)


# --- TIMER 5 DETIK & TRANSIKSI KE CUTSCENE HUTAN 2 ---
func start_cutscene_timer() -> void:
	await get_tree().create_timer(10.0).timeout

	# 1. Fade Out Layar (Tanpa fade out audio agar ambience terus menyambung ke cutscene_hutan_2)
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()

	# 2. Pindah ke cutscene_hutan_2.tscn
	var target_scene = "res://scene/Function/cutscene_hutan_2.tscn"
	get_tree().change_scene_to_file(target_scene)
