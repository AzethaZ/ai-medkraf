extends Node2D

@onready var trigger_area: Area2D = $TriggerArea
@onready var bird_sprite: Node2D = $BirdSprite
@onready var feather_item: Node2D = $FeatherItem

var has_triggered: bool = false

# Dialog Danum
var dialogue_ngedumel: Array[String] = [
	"Udara di hutan ini rasanya beda ya... aku jadi takut kalau sampai ada kebakaran."
]

var dialogue_bulu: Array[String] = [
	"Eh? Ada bulu burung jatuh... warnanya cantik sekali.",
	"Burungnya terbang ke arah sana, coba kuikuti..."
]

func _ready() -> void:
	if feather_item:
		feather_item.visible = false
	if bird_sprite:
		bird_sprite.visible = false

	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_entered)

func _on_trigger_entered(body: Node2D) -> void:
	if has_triggered:
		return

	if body.is_in_group("player") or body.name == "Player":
		has_triggered = true
		run_cutscene(body)

func run_cutscene(player: Node2D) -> void:
	# 1. KUNCI TOTAL PERGERAKAN PLAYER DI AWAL
	disable_player_movement(player, true)

	# 2. Danum Ngedumel
	DialogueManager.start_dialogue(dialogue_ngedumel, player)
	await DialogueManager.dialogue_finished

	# Kunci ulang Player (mencegah DialogueManager melepas kunci)
	disable_player_movement(player, true)

	# 3. Burung Terbang & Bulu Jatuh Fade Out (PLAYER TETAP TERKUNCI 100%)
	await animate_bird_and_feather()

	# Kunci ulang Player sebelum dialog kedua
	disable_player_movement(player, true)

	# 4. Danum Merespons Bulu yang Jatuh
	DialogueManager.start_dialogue(dialogue_bulu, player)
	await DialogueManager.dialogue_finished

	# 5. BUKA KEMBALI PERGERAKAN PLAYER SETELAH SEMUA PROSES SELESAI
	disable_player_movement(player, false)

func animate_bird_and_feather() -> void:
	if not bird_sprite or not feather_item:
		return

	# Posisi terbang burung (start di luar kiri, end jauh di luar kanan)
	var start_pos = Vector2(-450, -220)
	var end_pos = Vector2(550, -200)
	
	bird_sprite.position = start_pos
	bird_sprite.modulate.a = 1.0
	bird_sprite.visible = true
	
	feather_item.modulate.a = 1.0
	feather_item.visible = false

	# 1. Burung terbang meluncur ke kanan (durasi 3.5 detik)
	var tween_bird_move = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween_bird_move.tween_property(bird_sprite, "position", end_pos, 3.5)

	# FADE OUT BURUNG: Menunggu 2.5 detik (terbang lebih jauh ke kanan dulu) baru fade out
	var tween_bird_fade = create_tween()
	tween_bird_fade.tween_interval(2.5) # Durasi waktu terbang sebelum mulai memudar
	tween_bird_fade.tween_property(bird_sprite, "modulate:a", 0.0, 0.6) # Memudar dalam 0.6 detik
	tween_bird_fade.tween_callback(func(): bird_sprite.visible = false)

	# 2. Tunggu burung melintas di posisi pelepasan bulu (1.8 detik)
	await get_tree().create_timer(1.8).timeout

	# 3. Lepaskan bulu dari posisi burung saat itu
	var drop_origin = bird_sprite.position
	feather_item.position = drop_origin
	feather_item.visible = true

	# --- ANIMASI BULU MELAYANG PELAN ---
	var fall_duration = 2.4
	var target_y = 0.0 # Posisi tanah
	
	# Tween Jatuh ke tanah (Sumbu Y)
	var tween_fall = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween_fall.tween_property(feather_item, "position:y", target_y, fall_duration)

	# Tween Ayunan melayang ke kanan-kiri (Sumbu X)
	var tween_sway = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 20.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x - 10.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 25.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 15.0, 0.6)

	# Tween Rotasi bulu
	var tween_rot = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_rot.tween_property(feather_item, "rotation_degrees", 25.0, 0.6)
	tween_rot.tween_property(feather_item, "rotation_degrees", -20.0, 0.6)
	tween_rot.tween_property(feather_item, "rotation_degrees", 15.0, 0.6)
	tween_rot.tween_property(feather_item, "rotation_degrees", 0.0, 0.6)

	# --- FADE OUT BULU KETIKA HAMPIR MENYENTUH TANAH ---
	await get_tree().create_timer(1.6).timeout
	var tween_feather_fade = create_tween()
	tween_feather_fade.tween_property(feather_item, "modulate:a", 0.0, 0.8)

	# Tunggu sampai seluruh proses jatuh & fade out bulu selesai 100%
	await tween_fall.finished
	await tween_feather_fade.finished
	feather_item.visible = false

# --- FUNGSI KHUSUS UNTUK UNLOCK/LOCK PLAYER KETAT ---
func disable_player_movement(player: Node2D, is_disabled: bool) -> void:
	if not is_instance_valid(player):
		return

	# Hentikan gerak fisik & proses input
	player.set_physics_process(not is_disabled)
	player.set_process_input(not is_disabled)
	player.set_process_unhandled_input(not is_disabled)

	# Reset velocity player jika bertipe CharacterBody2D
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	# Hentikan/play animasi jalan/idle jika ada method bawaan
	if player.has_method("set_dialogue_state"):
		player.set_dialogue_state(is_disabled)
