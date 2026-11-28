extends Area2D

@export var target_quest_id: String = "quest_ayam_3"

@export_group("Cutscene Settings")
@export var rooster_voice_sfx: AudioStream # Masukkan file suara ayam di Inspector
@export var camera_pan_offset_x: float = -220.0 # Negatif = geser murni ke kiri
@export var camera_pan_duration: float = 2.0
@export var walk_distance: float = 180.0
@export var walk_speed: float = 160.0

@onready var interact_icon: Sprite2D = $InteractIcon if has_node("InteractIcon") else null
@onready var cutscene_trigger: Area2D = $RoosterCutsceneTrigger if has_node("RoosterCutsceneTrigger") else null

@export var rooster_bgm: AudioStream # <-- Drag & drop file musik rooster BGM di Inspector
@onready var rooster_bgm_player: AudioStreamPlayer = $RoosterBGMPlayer if has_node("RoosterBGMPlayer") else null

var is_player_inside: bool = false
var is_minigame_active: bool = false
var is_in_dialogue: bool = false
var is_cutscene_playing: bool = false
var player_ref: CharacterBody2D = null

var dialogue_lines: Array[String] = [
	"Akhirnya ketemu juga ayam jago ini...",
	"Mukanya galak banget kayak orang gendut di tv itu, harus ditangkep dulu nih!"
]

func _ready() -> void:
	if QuestManager.get_quest_status(target_quest_id) == "COMPLETED":
		queue_free()
		return

	if interact_icon:
		interact_icon.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if cutscene_trigger:
		if QuestManager.get_quest_status(target_quest_id) == "COMPLETED":
			cutscene_trigger.queue_free()
		else:
			cutscene_trigger.body_entered.connect(_on_cutscene_trigger_entered)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and not is_minigame_active and not is_in_dialogue and not is_cutscene_playing:
		var status = QuestManager.get_quest_status(target_quest_id)
		if status != "ACTIVE" and status != "COMPLETED":
			return

		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			start_intro_dialogue()


func start_intro_dialogue() -> void:
	# Jika ayam sudah pernah dikalahkan (sekarang ada di world_3), jalankan dialog jinak & batal masuk arena
	if GameState and GameState.get_meta("rooster_defeated", false):
		is_in_dialogue = true
		player_ref = get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D
		if not player_ref:
			is_in_dialogue = false
			return
		if interact_icon:
			interact_icon.visible = false
		_lock_player_for_cutscene(true)

		var tame_lines: Array[String] = [
			"Kukuruyuk! Aku sudah tenang dan kembali ke kandang sekarang."
		]
		DialogueManager.start_dialogue(tame_lines, self)
		await DialogueManager.dialogue_finished

		_lock_player_for_cutscene(false)
		is_in_dialogue = false
		return

	# === KODE ASLI PRE-BATTLE DI BAWAH INI ===
	is_in_dialogue = true
	player_ref = get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D
	if not player_ref:
		is_in_dialogue = false
		return

	if interact_icon:
		interact_icon.visible = false

	_lock_player_for_cutscene(true)

	DialogueManager.start_dialogue(dialogue_lines, player_ref)
	await DialogueManager.dialogue_finished

	is_in_dialogue = false
	start_transition_to_battle()

func start_transition_to_battle() -> void:
	if is_minigame_active:
		return
	is_minigame_active = true
	disable_player_movement(true)

	if interact_icon:
		interact_icon.visible = false

	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
	else:
		await get_tree().create_timer(0.4).timeout

	get_tree().change_scene_to_file("res://scene/Function/rooster_battle_arena.tscn")

# --- IN-GAME CUTSCENE SAAT MASUK AREA TRIGGER ---
func _on_cutscene_trigger_entered(body: Node2D) -> void:
	if is_cutscene_playing or is_minigame_active:
		return
	if not (body.is_in_group("player") or body.name.begins_with("Player")):
		return
	if QuestManager.get_quest_status(target_quest_id) != "ACTIVE":
		return

	is_cutscene_playing = true
	is_in_dialogue = true
	player_ref = body as CharacterBody2D

	await _play_rooster_cutscene()

	is_in_dialogue = false
	is_cutscene_playing = false
	if is_instance_valid(cutscene_trigger):
		cutscene_trigger.queue_free()

	# Langsung masuk ke gameplay fighting setelah dialog selesai
	start_transition_to_battle()

func _play_rooster_cutscene() -> void:
	_start_rooster_bgm() # <-- BGM lama langsung hilang, musik rooster mulai berputar
	# ... lanjutkan kode cutscene panning kamera & dialog rooster yang sudah ada ...
	if not player_ref:
		return

	var cam: Camera2D = player_ref.find_child("Camera2D", true, false)

	# 1. Bekukan _process & _physics_process player agar tidak mereset animasi ke "default"
	_lock_player_for_cutscene(true)
	_set_mc_walk_state(false)

	# 2. Kamera menggeser murni ke kiri (hanya sumbu X via offset.x)
	var orig_offset_x: float = cam.offset.x if cam else 0.0
	if cam:
		var target_offset_x: float = orig_offset_x + camera_pan_offset_x
		var cam_tween := create_tween()
		cam_tween.tween_property(cam, "offset:x", target_offset_x, camera_pan_duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await cam_tween.finished

	# 3. Suara ayam + dialog ayam
	_play_cutscene_sfx(rooster_voice_sfx)
	var rooster_lines: Array[String] = ["Kukuruyuk! Krrrk...!"]
	DialogueManager.start_dialogue(rooster_lines, self)
	await DialogueManager.dialogue_finished

	# 4. Kamera balik perlahan ke posisi MC
	if cam:
		var return_tween := create_tween()
		return_tween.tween_property(cam, "offset:x", orig_offset_x, camera_pan_duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await return_tween.finished

	# 5. MC membalas dialog pertama
	var mc_line_1: Array[String] = ["Itu ayamnya pasti... Mukanya galak banget kayak orang gendut di tv itu"]
	DialogueManager.start_dialogue(mc_line_1, player_ref)
	await DialogueManager.dialogue_finished

	# 6. MC berjalan maju ke arah ayam
	var dir: float = sign(global_position.x - player_ref.global_position.x)
	if dir == 0.0:
		dir = -1.0

	var start_x: float = player_ref.global_position.x
	var target_x: float = start_x + (dir * walk_distance)
	var walk_duration: float = abs(walk_distance) / max(walk_speed, 1.0)

	_lock_player_for_cutscene(true)

	var walk_tween := create_tween()
	walk_tween.tween_method(
		func(progress: float) -> void:
			if not is_instance_valid(player_ref):
				return
			player_ref.global_position.x = lerpf(start_x, target_x, progress)
			var sprite: AnimatedSprite2D = player_ref.get_node_or_null("AnimatedSprite2D")
			if sprite:
				sprite.flip_h = dir < 0
				if sprite.animation != "walk" or not sprite.is_playing():
					sprite.play("walk")
	, 0.0, 1.0, walk_duration)
	await walk_tween.finished

	_set_mc_walk_state(false)

	# 7. MC ngomong "Aku harus mengalahkannya!"
	var mc_line_2: Array[String] = ["Harus ditangkep dulu nih!"]
	DialogueManager.start_dialogue(mc_line_2, player_ref)
	await DialogueManager.dialogue_finished

func _lock_player_for_cutscene(locked: bool) -> void:
	if not player_ref:
		return
	player_ref.velocity = Vector2.ZERO
	player_ref.set_physics_process(not locked)
	player_ref.set_process(not locked)
	player_ref.set_process_unhandled_input(not locked)
	player_ref.set_process_input(not locked)

func _set_mc_walk_state(is_walking: bool) -> void:
	if not player_ref:
		return

	var anim_sprite: AnimatedSprite2D = player_ref.get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		anim_sprite.play("walk" if is_walking else "default")

func _flip_mc(facing_left: bool) -> void:
	if not player_ref:
		return
	var anim_sprite: AnimatedSprite2D = player_ref.get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		anim_sprite.flip_h = facing_left

func _play_cutscene_sfx(stream: AudioStream) -> void:
	if not stream:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func disable_player_movement(disable: bool) -> void:
	if not player_ref:
		player_ref = get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D

	if player_ref:
		if player_ref.has_method("set_dialogue_state"):
			player_ref.set_dialogue_state(disable)
		else:
			player_ref.set_physics_process(not disable)
			player_ref.set_process(not disable)

		if disable:
			player_ref.velocity = Vector2.ZERO

func _on_body_entered(body: Node2D) -> void:
	if is_cutscene_playing or is_minigame_active:
		return
	if body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_inside = true
		if QuestManager.get_quest_status(target_quest_id) == "ACTIVE" and interact_icon:
			interact_icon.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_inside = false
		if interact_icon:
			interact_icon.visible = false
		if not is_cutscene_playing:
			is_in_dialogue = false

func _start_rooster_bgm() -> void:
	# 1. Hentikan BGM world yang sedang berjalan lewat MusicManager
	if has_node("/root/MusicManager"):
		var mm = get_node("/root/MusicManager")
		if mm.has_method("stop_music"):
			mm.stop_music()
		elif mm.has_method("stop_bgm"):
			mm.stop_bgm()
		else:
			# Fallback jika MusicManager berupa AudioStreamPlayer atau punya child AudioStreamPlayer
			if mm is AudioStreamPlayer:
				mm.stop()
			for child in mm.get_children():
				if child is AudioStreamPlayer:
					child.stop()

	# 2. Putar Rooster BGM
	if rooster_bgm and rooster_bgm_player:
		rooster_bgm_player.stream = rooster_bgm
		rooster_bgm_player.play()
