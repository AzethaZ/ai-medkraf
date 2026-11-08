extends Node2D

@onready var trigger_area: Area2D = $TriggerArea if has_node("TriggerArea") else null
@onready var bird_sprite: Node2D = $BirdSprite if has_node("BirdSprite") else null
@onready var feather_item: Node2D = $FeatherItem if has_node("FeatherItem") else null
@onready var bird_sfx: AudioStreamPlayer = $BirdSFX if has_node("BirdSFX") else null
@onready var bird_chirp_sfx: AudioStreamPlayer = $BirdChirpSFX if has_node("BirdChirpSFX") else null

var has_triggered: bool = false

# Dialog Danum Cutscene 1
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
	# 1. Kunci pergerakan player
	disable_player_movement(player, true)

	# 2. Danum ngedumel awal
	if DialogueManager:
		DialogueManager.start_dialogue(dialogue_ngedumel, player)
		await DialogueManager.dialogue_finished

	disable_player_movement(player, true)

	# 3. Burung terbang melintas + SFX Kepakan & Kicauan + Bulu jatuh sampai tanah
	await animate_bird_and_feather()

	disable_player_movement(player, true)

	# 4. Danum merespons bulu jatuh
	if DialogueManager:
		DialogueManager.start_dialogue(dialogue_bulu, player)
		await DialogueManager.dialogue_finished

	# 5. Buka kembali kontrol player
	disable_player_movement(player, false)

func animate_bird_and_feather() -> void:
	if not bird_sprite or not feather_item:
		return

	# Set titik spawn jauh di luar kiri layar
	var start_pos = Vector2(-650, -220)
	var end_pos = Vector2(700, -200)

	bird_sprite.position = start_pos
	bird_sprite.modulate.a = 1.0
	bird_sprite.visible = true

	feather_item.modulate.a = 1.0
	feather_item.visible = false

	# 1. Pergerakan terbang burung
	var tween_bird_move = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween_bird_move.tween_property(bird_sprite, "position", end_pos, 4.0)

	# --- MEMUTAR SFX SAAT BURUNG MASUK LAYAR ---
	get_tree().create_timer(0.7).timeout.connect(func():
		# Suara Kepakan Sayap
		if bird_sfx and bird_sfx.stream:
			bird_sfx.volume_db = -6.0
			bird_sfx.play()

		# Suara Kicauan Burung (Jeda 0.2 detik setelah terbang)
		get_tree().create_timer(0.2).timeout.connect(func():
			if bird_chirp_sfx and bird_chirp_sfx.stream:
				bird_chirp_sfx.volume_db = -15.0
				bird_chirp_sfx.pitch_scale = randf_range(0.95, 1.1)
				bird_chirp_sfx.play()
		)
	)

	# Fade out burung di kanan layar
	var tween_bird_fade = create_tween()
	tween_bird_fade.tween_interval(3.0)
	tween_bird_fade.tween_property(bird_sprite, "modulate:a", 0.0, 0.6)
	tween_bird_fade.tween_callback(func(): bird_sprite.visible = false)

	# 2. Pelepasan bulu saat burung melintas di atas
	await get_tree().create_timer(1.8).timeout

	var drop_origin = bird_sprite.position
	feather_item.position = drop_origin
	feather_item.visible = true

	var fall_duration = 2.4
	var target_y = 30.0 # Posisi pendaratan tanah

	# Tween Jatuh Y & Ayunan X
	var tween_fall = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween_fall.tween_property(feather_item, "position:y", target_y, fall_duration)

	var tween_sway = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 20.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x - 10.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 25.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 15.0, 0.6)

	var tween_rot = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_rot.tween_property(feather_item, "rotation_degrees", 25.0, 0.6)
	tween_rot.tween_property(feather_item, "rotation_degrees", -20.0, 0.6)
	tween_rot.tween_property(feather_item, "rotation_degrees", 15.0, 0.6)
	tween_rot.tween_property(feather_item, "rotation_degrees", 0.0, 0.6)

	await tween_fall.finished

# --- HELPER UNLOCK/LOCK PLAYER ---
func disable_player_movement(player: Node2D, is_disabled: bool) -> void:
	if not is_instance_valid(player):
		return

	player.set_physics_process(not is_disabled)
	player.set_process_input(not is_disabled)
	player.set_process_unhandled_input(not is_disabled)

	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	if player.has_method("set_dialogue_state"):
		player.set_dialogue_state(is_disabled)
