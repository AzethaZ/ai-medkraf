extends CharacterBody2D

@export var farm_chick_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var chat_detection: Area2D = $chat_detection if has_node("chat_detection") else null
@onready var interact_icon: Sprite2D = $InteractIcon if has_node("InteractIcon") else null

@onready var dialogue_ui: Control = $DialogueUI if has_node("DialogueUI") else null
@onready var dialogue_box: PanelContainer = $DialogueUI/PanelContainer if has_node("DialogueUI/PanelContainer") else null
@onready var dialogue_label: Label = $DialogueUI/PanelContainer/VBoxContainer/Label if has_node("DialogueUI/PanelContainer/VBoxContainer/Label") else null

var should_complete_quest_on_end: bool = false
var should_start_quest_on_end: bool = false
var current_active_quest: String = ""

var is_player_in_chat_zone: bool = false
var is_chatting: bool = false
var current_line_index: int = 0
var dialogue_lines: Array[String] = []
var tween: Tween
var text_tween: Tween


func _ready() -> void:
	if dialogue_ui:
		dialogue_ui.visible = false
	if interact_icon:
		interact_icon.visible = false

	# Jika quest ayam 1 sudah selesai sebelumnya, tampilkan ayam di kandang Peternak
	if QuestManager and QuestManager.get_quest_status("quest_ayam_1") == "COMPLETED":
		spawn_farm_chicks()

	if chat_detection:
		if not chat_detection.body_entered.is_connected(_on_chat_detection_body_entered):
			chat_detection.body_entered.connect(_on_chat_detection_body_entered)
		if not chat_detection.body_exited.is_connected(_on_chat_detection_body_exited):
			chat_detection.body_exited.connect(_on_chat_detection_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	# Cek aman menggunakan operator 'in' di Godot
	if DialogueManager and "is_active" in DialogueManager and DialogueManager.is_active:
		return

	if is_player_in_chat_zone and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		start_dialogue()


func prepare_dialogue_lines() -> void:
	should_start_quest_on_end = false
	should_complete_quest_on_end = false
	current_active_quest = ""

	var q1_status = QuestManager.get_quest_status("quest_ayam_1") if QuestManager else "NOT_STARTED"
	var q3_status = QuestManager.get_quest_status("quest_ayam_3") if QuestManager else "NOT_STARTED"
	var q1_count = QuestManager.get_quest_progress("quest_ayam_1") if QuestManager else 0

	# --- TAHAP 1: QUEST ANAK AYAM ---
	if q1_status == "NOT_STARTED":
		current_active_quest = "quest_ayam_1"
		should_start_quest_on_end = true
		dialogue_lines = [
			"Tolong! Anak-anak ayamku lepas sampai ke area sekitar hutan!",
			"Bisa tolong kumpulkan 3 anak ayam dan bawa kembali ke sini?"
		]

	elif q1_status == "ACTIVE" or q1_status == "READY_TO_SUBMIT":
		if q1_count >= 3 or q1_status == "READY_TO_SUBMIT":
			current_active_quest = "quest_ayam_1"
			should_complete_quest_on_end = true
			dialogue_lines = [
				"Terima kasih banyak atas bantuanmu, Danum! Anak-anak ayam sudah kembali aman.",
				"Tapi ada masalah lain! Ayam Jago galakku kabur sampai ke area sungai di World 1!",
				"Akses jalan ke area tersebut sudah aku bukakan. Tolong bantu tangkap dia ya!"
			]
		else:
			dialogue_lines = [
				"Kamu baru menemukan " + str(q1_count) + "/3 anak ayam...",
				"Coba cari lagi di area sebelah kanan dan map sekitar!"
			]

	# --- TAHAP 2: QUEST AYAM JAGO GALAK ---
	elif q3_status == "ACTIVE":
		var q3_count = QuestManager.get_quest_progress("quest_ayam_3") if QuestManager else 0
		if q3_count >= 1:
			current_active_quest = "quest_ayam_3"
			should_complete_quest_on_end = true
			dialogue_lines = [
				"Hebat sekali! Ayam jago galak berhasil kamu tangkap!",
				"Semua unggas peternakanku sudah kembali lengkap. Terima kasih banyak, Danum!"
			]
		else:
			dialogue_lines = [
				"Ayam jago galak itu masih berkeliaran di World 1!",
				"Hati-hati ya Danum, patukannya lumayan sakit!"
			]

	elif q3_status == "COMPLETED" or q1_status == "COMPLETED":
		dialogue_lines = [
			"Semua ayam sudah aman di kandang. Terima kasih banyak atas bantuanmu, Danum!"
		]


func start_dialogue() -> void:
	is_chatting = true
	if interact_icon:
		interact_icon.visible = false
		stop_hover_animation()

	prepare_dialogue_lines()

	if DialogueManager and DialogueManager.has_method("start_dialogue"):
		await DialogueManager.start_dialogue(dialogue_lines, self)
		if DialogueManager.has_signal("dialogue_finished"):
			await DialogueManager.dialogue_finished
		elif DialogueManager.has_signal("dialogue_ended"):
			await DialogueManager.dialogue_ended
		process_quest_after_dialogue()
	else:
		current_line_index = 0
		if dialogue_ui:
			dialogue_ui.visible = true
		show_current_line()


func show_current_line() -> void:
	if text_tween and text_tween.is_running():
		text_tween.kill()

	if dialogue_label and current_line_index < dialogue_lines.size():
		dialogue_label.text = dialogue_lines[current_line_index]
		dialogue_label.visible_ratio = 0.0
		var duration = dialogue_lines[current_line_index].length() * 0.03
		text_tween = create_tween()
		text_tween.tween_property(dialogue_label, "visible_ratio", 1.0, duration)


func advance_dialogue() -> void:
	current_line_index += 1
	if current_line_index < dialogue_lines.size():
		show_current_line()
	else:
		end_dialogue()


func end_dialogue() -> void:
	is_chatting = false
	if dialogue_ui:
		dialogue_ui.visible = false

	process_quest_after_dialogue()


func process_quest_after_dialogue() -> void:
	if should_start_quest_on_end and current_active_quest != "":
		if QuestManager and QuestManager.has_method("start_quest"):
			QuestManager.start_quest(current_active_quest)
		should_start_quest_on_end = false

	if should_complete_quest_on_end and current_active_quest != "":
		if current_active_quest == "quest_ayam_1":
			if SceneTransition and SceneTransition.has_method("fade_out"):
				await SceneTransition.fade_out()

			var player = get_tree().current_scene.find_child("Player", true, false)
			if player and player.has_method("clear_followers"):
				player.clear_followers()

			if GameManager and GameManager.has_method("clear_followers_data"):
				GameManager.clear_followers_data()

			if QuestManager:
				QuestManager.complete_quest("quest_ayam_1")
			spawn_farm_chicks()

			if QuestManager:
				QuestManager.start_quest("quest_ayam_3")

			await get_tree().create_timer(0.3).timeout

			if SceneTransition and SceneTransition.has_method("fade_in"):
				await SceneTransition.fade_in()
		else:
			if QuestManager:
				QuestManager.complete_quest(current_active_quest)

		should_complete_quest_on_end = false

	is_chatting = false
	if is_player_in_chat_zone and interact_icon:
		interact_icon.visible = true
		start_hover_animation()


func spawn_farm_chicks() -> void:
	if get_tree().current_scene.has_node("FarmChick_1"):
		return

	if farm_chick_scene:
		var offsets = [Vector2(-60, 5), Vector2(50, 5), Vector2(-110, 5)]
		for i in range(3):
			var new_chick = farm_chick_scene.instantiate() as Node2D
			new_chick.name = "FarmChick_" + str(i + 1)
			new_chick.global_position = global_position + offsets[i]
			get_tree().current_scene.add_child.call_deferred(new_chick)


func _on_chat_detection_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_in_chat_zone = true
		if interact_icon and not is_chatting:
			interact_icon.visible = true
			start_hover_animation()


func _on_chat_detection_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_in_chat_zone = false
		if interact_icon:
			interact_icon.visible = false
			stop_hover_animation()


func start_hover_animation() -> void:
	if not interact_icon: return
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_loops()
	tween.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
