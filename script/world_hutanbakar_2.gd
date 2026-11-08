extends Node2D

@onready var player: Node2D = $Player
@onready var camera_2d: Camera2D = find_child("Camera2D", true, false)

@onready var interact_kiri: Area2D = find_child("InteractKiri", true, false)
@onready var interact_kanan: Area2D = find_child("InteractKanan", true, false)
@onready var area_exit: Area2D = find_child("AreaExit", true, false)

var interacted_count: int = 0
const TOTAL_REQUIRED: int = 2
var cutscene_triggered: bool = false

func _ready() -> void:
	# 0. AKTIFKAN MODE PINCANG & DISABLE LARI UNTUK DANUM
	if player and player.has_method("set_limping_mode"):
		player.set_limping_mode(true)

	# 1. Nonaktifkan AreaExit agar pemain tidak bisa keluar map dulu
	if area_exit:
		area_exit.monitoring = false

	# 2. Setup Kamera
	if camera_2d:
		camera_2d.enabled = true
		camera_2d.make_current()

	# 3. Hubungkan signal dari 2 objek interactable (kiri & kanan)
	if interact_kiri and interact_kiri.has_signal("interacted"):
		interact_kiri.interacted.connect(_on_objek_interacted)
	if interact_kanan and interact_kanan.has_signal("interacted"):
		interact_kanan.interacted.connect(_on_objek_interacted)

	# 4. Fade In masuk ke Hutan Terbakar
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 5. Pemain langsung bisa bebas berjalan
	if player and player.has_method("enable_movement"):
		player.enable_movement()

	# 6. Kalimat Pertama: Langsung muncul saat pertama kali masuk scene
	play_initial_dialogue()

func _exit_tree() -> void:
	# KEMBALIKAN KONTROL DANUM KE NORMAL SAAT SCENE DITINGGALKAN
	if is_instance_valid(player) and player.has_method("set_limping_mode"):
		player.set_limping_mode(false)

# --- KALIMAT PERTAMA (LANGSUNG SAAT MASUK SCENE) ---
func play_initial_dialogue() -> void:
	if player and player.has_method("show_dialogue"):
		player.show_dialogue("Uhkh... Hutan... terbakar?! Aku harus keluar dari sini!", 3.0)

# --- FUNGSI PENGHITUNG INTERAKSI & DIALOG INTERAKSI ---
func _on_objek_interacted() -> void:
	interacted_count += 1
	print("Interaksi berhasil: ", interacted_count, "/", TOTAL_REQUIRED)

	# Kalimat Kedua & Ketiga: Muncul saat player berinteraksi dengan objek
	play_interaction_dialogue(interacted_count)

	if interacted_count >= TOTAL_REQUIRED and not cutscene_triggered:
		cutscene_triggered = true
		start_cutscene_timer()

# --- KALIMAT KEDUA DAN KETIGA (SAAT INTERACT) ---
func play_interaction_dialogue(step: int) -> void:
	if player and player.has_method("show_dialogue"):
		if step == 1:
			# Dialog saat interaksi pertama (misal: memeriksa objek pertama)
			player.show_dialogue("Tolong! Ada orang di sini?! Api semakin membesar!", 2.5)
		elif step == 2:
			# Dialog saat interaksi kedua (puncak kepanikan sebelum pingsan)
			player.show_dialogue("Nafasku... terengah-engah... aku tidak tahan lagi...", 3.0)

# --- TIMER 5 DETIK & TRANSIKSI KE WORLD LANGIT ---
func start_cutscene_timer() -> void:
	# Jeda 5 detik setelah kedua interaksi selesai
	await get_tree().create_timer(5.0).timeout

	# Fade Out Layar
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()

	# Pindah Scene ke world_langit.tscn
	var target_scene = "res://scene/World/world_langit.tscn"
	if not ResourceLoader.exists(target_scene):
		target_scene = "res://scene/world_langit.tscn"

	get_tree().change_scene_to_file(target_scene)
