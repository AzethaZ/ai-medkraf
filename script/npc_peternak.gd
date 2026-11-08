extends CharacterBody2D

@export var farm_chick_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var chat_detection: Area2D = $chat_detection
@onready var interact_icon: Sprite2D = $InteractIcon

var should_complete_quest_on_end: bool = false
var should_start_quest_on_end: bool = false
var current_active_quest: String = ""

@onready var dialogue_ui: Control = $DialogueUI
@onready var dialogue_box: PanelContainer = $DialogueUI/PanelContainer
@onready var dialogue_label: Label = $DialogueUI/PanelContainer/VBoxContainer/Label

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

	if QuestManager.get_quest_status("quest_ayam_1") == "COMPLETED":
		spawn_farm_chicks()

func _unhandled_input(event: InputEvent) -> void:
	# Jika dialog sedang aktif, abaikan input dari NPC agar tidak bentrok dengan DialogueManager
	if DialogueManager.is_active:
		return

	if is_player_in_chat_zone and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		start_dialogue()

func prepare_dialogue_lines() -> void:
	should_start_quest_on_end = false
	should_complete_quest_on_end = false
	current_active_quest = ""

	var q1 = QuestManager.get_quest_status("quest_ayam_1")
	var q3 = QuestManager.get_quest_status("quest_ayam_3")

	# --- TAHAP 1: QUEST ANAK AYAM (0/3) ---
	if q1 == "NOT_STARTED":
		current_active_quest = "quest_ayam_1"
		should_start_quest_on_end = true
		dialogue_lines = [
			"Tolong! Anak-anak ayamku lepas ke arah kanan!",
			"Bisa tolong kumpulkan 3 anak ayam dan bawa kembali ke sini?"
		]
	elif q1 == "ACTIVE":
		var count = QuestManager.get_quest_progress("quest_ayam_1")
		if count >= 3:
			current_active_quest = "quest_ayam_1"
			should_complete_quest_on_end = true
			dialogue_lines = [
				"Terima kasih banyak atas bantuanmu, Danum! Anak-anak ayam sudah kembali aman.",
				"Tapi ada masalah lain! Ayam Jago galakku kabur sampai ke area sungai (World 3)!",
				"Akses ke sungai sudah aku bukakan. Tolong bantu tangkap dia ya!"
			]
			var player = get_tree().current_scene.find_child("Player", true, false)
			if player and player.has_method("clear_followers"):
				player.clear_followers()
		else:
			dialogue_lines = [
				"Kamu baru menemukan " + str(count) + "/3 anak ayam...",
				"Coba cari lagi di sebelah kanan!"
			]

	# --- TAHAP 2: QUEST AYAM JAGO GALAK (0/1) ---
	elif q3 == "ACTIVE":
		var count = QuestManager.get_quest_progress("quest_ayam_3")
		if count >= 1:
			current_active_quest = "quest_ayam_3"
			should_complete_quest_on_end = true
			dialogue_lines = [
				"Hebat sekali! Ayam jago galak berhasil kamu tangkap!",
				"Semua unggas peternakanku sudah kembali lengkap. Terima kasih banyak, Danum!"
			]
			var player = get_tree().current_scene.find_child("Player", true, false)
			if player and player.has_method("clear_followers"):
				player.clear_followers()
		else:
			dialogue_lines = [
				"Ayam jago galak itu masih berkeliaran di area sungai!"
			]

	elif q3 == "COMPLETED":
		dialogue_lines = [
			"Semua ayam sudah aman di kandang. Terima kasih banyak, Danum!"
		]

func start_dialogue() -> void:
	is_chatting = true

	if interact_icon:
		interact_icon.visible = false
		stop_hover_animation()

	prepare_dialogue_lines()

	# 1. Jalankan dialogue manager global
	DialogueManager.start_dialogue(dialogue_lines, self)
	
	# 2. Tunggu sampai percakapan selesai
	await DialogueManager.dialogue_finished
	
	# 3. Jalankan efek & pemicu quest sesuai status
	process_quest_after_dialogue()
	
	is_chatting = false

	if is_player_in_chat_zone and interact_icon:
		interact_icon.visible = true
		start_hover_animation()

func process_quest_after_dialogue() -> void:
	# Aktifkan quest baru jika diset
	if should_start_quest_on_end and current_active_quest != "":
		QuestManager.start_quest(current_active_quest)
		should_start_quest_on_end = false

	# Selesaikan quest jika diset
	if should_complete_quest_on_end and current_active_quest != "":
		if current_active_quest == "quest_ayam_1":
			if SceneTransition and SceneTransition.has_method("fade_out"):
				await SceneTransition.fade_out()

			QuestManager.complete_quest("quest_ayam_1")
			spawn_farm_chicks()

			# Trigger Quest 3 (Ayam Jago)
			QuestManager.start_quest("quest_ayam_3")

			await get_tree().create_timer(0.3).timeout

			if SceneTransition and SceneTransition.has_method("fade_in"):
				await SceneTransition.fade_in()
		else:
			QuestManager.complete_quest(current_active_quest)

		should_complete_quest_on_end = false

func show_current_line() -> void:
	if text_tween and text_tween.is_running():
		text_tween.kill()

	dialogue_label.text = dialogue_lines[current_line_index]
	dialogue_box.reset_size()
	dialogue_box.position.x = -dialogue_box.size.x / 2.0

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
	dialogue_ui.visible = false

	if should_start_quest_on_end and current_active_quest != "":
		QuestManager.start_quest(current_active_quest)
		should_start_quest_on_end = false

	if should_complete_quest_on_end and current_active_quest != "":
		if current_active_quest == "quest_ayam_1":
			# 1. Fade out saat penyerahan anak ayam
			if SceneTransition and SceneTransition.has_method("fade_out"):
				await SceneTransition.fade_out()

			# 2. Selesaikan Quest 1
			QuestManager.complete_quest("quest_ayam_1")
			spawn_farm_chicks()

			# 3. Langsung aktifkan Quest 3 (Ayam Jago Galak) oleh sistem
			QuestManager.start_quest("quest_ayam_3")

			await get_tree().create_timer(0.3).timeout

			# 4. Fade in kembali ke game
			if SceneTransition and SceneTransition.has_method("fade_in"):
				await SceneTransition.fade_in()
		else:
			QuestManager.complete_quest(current_active_quest)

		should_complete_quest_on_end = false

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
		if is_chatting:
			is_chatting = false
			dialogue_ui.visible = false
			should_start_quest_on_end = false
			should_complete_quest_on_end = false

func start_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_loops()
	tween.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
