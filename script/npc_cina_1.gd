extends Node2D

@onready var interact_icon: Node2D = $InteractIcon if has_node("InteractIcon") else null
@onready var chat_detection: Area2D = $chat_detection if has_node("chat_detection") else null
@onready var cutscene_trigger: Area2D = $CutsceneTrigger if has_node("CutsceneTrigger") else null
@onready var dialogue_pivot: Marker2D = $DialoguePivot if has_node("DialoguePivot") else null

var player_in_range: bool = false
var hover_tween: Tween
var dialogue_index: int = 0
var is_cutscene_playing: bool = false

func _ready() -> void:
	# Jika cutscene sudah pernah dipicu sebelumnya, langsung hapus trigger permanen
	if GameState.npc_cina_cutscene_triggered:
		if cutscene_trigger:
			cutscene_trigger.queue_free()
	else:
		if cutscene_trigger:
			cutscene_trigger.body_entered.connect(_on_cutscene_trigger_body_entered)

	if interact_icon:
		interact_icon.visible = false

	if chat_detection:
		chat_detection.body_entered.connect(_on_chat_detection_body_entered)
		chat_detection.body_exited.connect(_on_chat_detection_body_exited)

func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name.to_lower().contains("player")

func _check_quest_triggered() -> bool:
	if not QuestManager:
		return false

	if QuestManager.has_method("get_quest_status"):
		var status: String = QuestManager.get_quest_status("quest_ayam_1")
		if status == "ACTIVE" or status == "READY_TO_SUBMIT" or status == "COMPLETED":
			return true

	return false

# --- BAGIAN INTERAKSI BIASA (CHAT & ICON) ---
func _on_chat_detection_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = true
		# Ikon tetap muncul kapan saja pemain mendekat, asalkan cutscene tidak sedang berjalan
		if interact_icon and not is_cutscene_playing:
			interact_icon.visible = true
			_start_hover_tween()

func _on_chat_detection_body_exited(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = false
		if interact_icon:
			interact_icon.visible = false
			_stop_hover_tween()

func _start_hover_tween() -> void:
	if not interact_icon:
		return
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()

	var base_y: float = interact_icon.position.y
	hover_tween = create_tween().set_loops()
	hover_tween.tween_property(interact_icon, "position:y", base_y - 4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_tween.tween_property(interact_icon, "position:y", base_y + 4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_hover_tween() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()

func _unhandled_input(event: InputEvent) -> void:
	if is_cutscene_playing:
		return

	if player_in_range and event.is_action_pressed("interact"):
		if DialogueManager and "is_active" in DialogueManager and DialogueManager.is_active:
			return
		_start_normal_dialogue()

# --- DIALOG BIASA (2 KALIMAT / 2 KALI INTERACT) ---
func _start_normal_dialogue() -> void:
	if not DialogueManager:
		return

	# Sembunyikan ikon sementara saat ngobrol, tapi jangan ubah player_in_range menjadi false
	if interact_icon:
		interact_icon.visible = false
		_stop_hover_tween()

	var is_quest_triggered: bool = _check_quest_triggered()
	var dialogue_pool: Array[String] = []

	if is_quest_triggered:
		dialogue_pool = [
			"Anak ayam suka dengan melodi, jadi coba ikuti ketukannya.",
			"Dengarkan baik-baik irama di sekitar sini ya!"
		]
	else:
		dialogue_pool = [
			"Ayam-ayam di sini sakti banget hari ini, suka berkeliaran ke sana kemari...",
			"Kalau kamu mau cari mereka, pastikan teliti ya!"
		]

	var current_line: String = dialogue_pool[dialogue_index]
	dialogue_index = (dialogue_index + 1) % dialogue_pool.size()

	var target_pivot: Node2D
	if is_instance_valid(dialogue_pivot):
		target_pivot = dialogue_pivot
	else:
		target_pivot = self

	DialogueManager.start_dialogue([current_line], target_pivot)

	# Tunggu dialog selesai lalu munculkan kembali ikon interact jika pemain masih di dekat NPC
	if "is_active" in DialogueManager:
		while DialogueManager.is_active:
			await get_tree().process_frame
	elif DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	elif DialogueManager.has_signal("dialogue_ended"):
		await DialogueManager.dialogue_ended

	if player_in_range and interact_icon and not is_cutscene_playing:
		interact_icon.visible = true
		_start_hover_tween()

# --- CUTSCENE TRIGGER (SAAT PEMAIN MENGINJAK AREA SETELAH QUEST AKTIF) ---
func _on_cutscene_trigger_body_entered(body: Node2D) -> void:
	if GameState.npc_cina_cutscene_triggered:
		if cutscene_trigger:
			cutscene_trigger.queue_free()
		return

	if _is_player(body):
		var is_quest_triggered: bool = _check_quest_triggered()

		if is_quest_triggered:
			GameState.npc_cina_cutscene_triggered = true

			if interact_icon:
				interact_icon.visible = false
				_stop_hover_tween()

			if cutscene_trigger:
				cutscene_trigger.queue_free()

			_play_cutscene(body)

func _play_cutscene(player: Node2D) -> void:
	is_cutscene_playing = true

	if "can_move" in player:
		player.can_move = false
	elif player.has_method("disable_input"):
		player.disable_input()

	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam:
		var npc_pos: Vector2 = dialogue_pivot.global_position if is_instance_valid(dialogue_pivot) else global_position
		var target_pos: Vector2 = Vector2(npc_pos.x, cam.global_position.y)

		var pan_tween = create_tween()
		pan_tween.tween_property(cam, "global_position", target_pos, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await pan_tween.finished

	var dialogue_lines: Array[String] = [
		"Anak ayam suka dengan melodi, jadi coba ikuti ketukannya."
	]

	var target_pivot: Node2D
	if is_instance_valid(dialogue_pivot):
		target_pivot = dialogue_pivot
	else:
		target_pivot = self

	if DialogueManager and DialogueManager.has_method("start_dialogue"):
		DialogueManager.start_dialogue(dialogue_lines, target_pivot)

	if "is_active" in DialogueManager:
		while DialogueManager.is_active:
			await get_tree().process_frame
	elif DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	elif DialogueManager.has_signal("dialogue_ended"):
		await DialogueManager.dialogue_ended

	if cam:
		var return_pos: Vector2 = Vector2(player.global_position.x, cam.global_position.y)
		var return_tween = create_tween()
		return_tween.tween_property(cam, "global_position", return_pos, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await return_tween.finished

	if "can_move" in player:
		player.can_move = true
	elif player.has_method("enable_input"):
		player.enable_input()

	is_cutscene_playing = false

	# Jika setelah cutscene selesai pemain berada di dekat NPC, munculkan ikon interaksi
	if player_in_range and interact_icon:
		interact_icon.visible = true
		_start_hover_tween()
