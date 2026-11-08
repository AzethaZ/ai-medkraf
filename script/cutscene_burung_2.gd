extends Node2D

@onready var trigger_area: Area2D = $TriggerArea if has_node("TriggerArea") else null
@onready var bird_sprite: Node2D = $BirdSprite if has_node("BirdSprite") else null
@onready var feather_item: Node2D = $FeatherItem if has_node("FeatherItem") else null
@onready var bird_sfx: AudioStreamPlayer = $BirdSFX if has_node("BirdSFX") else null
@onready var bird_chirp_sfx: AudioStreamPlayer = $BirdChirpSFX if has_node("BirdChirpSFX") else null

var has_triggered: bool = false

# Dialog Danum Cutscene 2
var dialogue_stage_2: Array[String] = [
	"Eh? Ada bulu burung jatuh lagi...",
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
		run_cutscene_2(body)

func run_cutscene_2(player: Node2D) -> void:
	# 1. Kunci Pergerakan Player
	disable_player_movement(player, true)

	# 2. Burung Terbang + SFX Kepakan & Kicauan + Bulu Jatuh ke Tanah (No Fade Out)
	await animate_bird_and_feather_drop()

	# 3. Danum Merespons Dialog Bulu Jatuh
	disable_player_movement(player, true)
	if DialogueManager:
		DialogueManager.start_dialogue(dialogue_stage_2, player)
		await DialogueManager.dialogue_finished

	# 4. Buka kembali kontrol player (Bulu TETAP STICK DI TANAH)
	disable_player_movement(player, false)

func animate_bird_and_feather_drop() -> void:
	if not bird_sprite or not feather_item:
		return

	# Coordinate spawn dari luar layar kiri (-650)
	var start_pos = Vector2(-650, -220)
	var end_pos = Vector2(700, -200)

	bird_sprite.position = start_pos
	bird_sprite.modulate.a = 1.0
	bird_sprite.visible = true

	feather_item.modulate.a = 1.0
	feather_item.visible = false

	# 1. Burung terbang meluncur ke kanan
	var tween_bird_move = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween_bird_move.tween_property(bird_sprite, "position", end_pos, 4.0)

	# --- MEMUTAR SFX KEPAKAN & KICAUAN ---
	get_tree().create_timer(0.7).timeout.connect(func():
		# Suara Kepakan Sayap
		if bird_sfx and bird_sfx.stream:
			bird_sfx.volume_db = -6.0
			bird_sfx.play()

		# Suara Kicauan Burung
		get_tree().create_timer(0.2).timeout.connect(func():
			if bird_chirp_sfx and bird_chirp_sfx.stream:
				bird_chirp_sfx.volume_db = -8.0
				bird_chirp_sfx.pitch_scale = randf_range(0.95, 1.1)
				bird_chirp_sfx.play()
		)
	)

	# Fade out burung di kanan layar
	var tween_bird_fade = create_tween()
	tween_bird_fade.tween_interval(3.0)
	tween_bird_fade.tween_property(bird_sprite, "modulate:a", 0.0, 0.6)
	tween_bird_fade.tween_callback(func(): bird_sprite.visible = false)

	# 2. Pelepasan bulu burung saat di tengah layar
	await get_tree().create_timer(1.8).timeout

	var drop_origin = bird_sprite.position
	feather_item.position = drop_origin
	feather_item.visible = true

	var fall_duration = 0.2
	var target_y = 30.0 # Posisi pendaratan permukaan tanah

	# Tween Jatuh Sumbu Y
	var tween_fall = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween_fall.tween_property(feather_item, "position:y", target_y, fall_duration)

	# Tween Ayunan Melayang (Sumbu X)
	var tween_sway = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 20.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x - 10.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 25.0, 0.6)
	tween_sway.tween_property(feather_item, "position:x", drop_origin.x + 15.0, 0.6)

	# Tween Rotasi Bulu
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
