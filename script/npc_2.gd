extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var chat_detection: Area2D = $chat_detection
@onready var interact_icon: Sprite2D = $InteractIcon
@onready var campfire: AnimatedSprite2D = $Campfire # Sesuaikan jika nama nodemu AnimatedSprite2D
var should_complete_quest_on_end: bool = false
var should_start_quest_on_end: bool = false

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
	# 1. Sembunyikan UI dialog & ikon di awal
	if dialogue_ui:
		dialogue_ui.visible = false
	if interact_icon:
		interact_icon.visible = false

	# 2. Cek status quest untuk menentukan apakah api unggun muncul
	var is_completed = QuestManager.is_quest_completed("collect_wood")
	if campfire:
		campfire.visible = is_completed

	# 3. Hubungkan signal area interaksi pemain (jika belum via Editor)
	# Pastikan Area2D interaksi NPC terhubung ke fungsi _on_body_entered & _on_body_exited

func _unhandled_input(event: InputEvent) -> void:
	if is_player_in_chat_zone and event.is_action_pressed("interact"):
		if not is_chatting:
			start_dialogue()
		else:
			if text_tween and text_tween.is_running():
				text_tween.kill()
				dialogue_label.visible_ratio = 1.0
			else:
				advance_dialogue()


func prepare_dialogue_lines() -> void:
	var status = QuestManager.quests["collect_wood"]["status"]
	var wood_count = GameManager.get_item_count("wood")
	
	should_start_quest_on_end = false # Reset flag
	
	match status:
		"NOT_STARTED":
			# Tandai bahwa quest akan dimulai NANTI setelah dialog selesai
			should_start_quest_on_end = true
			
			dialogue_lines = [
				"Halo! Aku sedang membutuhkan kayu untuk membuat api unggun.",
				"Bisakah kamu mengumpulkan 4 balok kayu (Wood) untukku?"
			]
			
		"ACTIVE":
			if wood_count >= 4:
				# Ganti GameManager.remove_item dan QuestManager.complete_quest dari sini
				# Tandai flag ini untuk dijalankan di end_dialogue()
				should_complete_quest_on_end = true
				
				dialogue_lines = [
					"Wah, kamu membawa 4 balok kayu!",
					"Terima kasih banyak, ini sangat membantu.",
					"Tunggu sebentar, aku akan menyalakan api unggunnya..."
				]
			else:
				var sisa = 4 - wood_count
				dialogue_lines = [
					"Kamu baru punya " + str(wood_count) + " kayu.",
					"Aku masih membutuhkan " + str(sisa) + " kayu lagi."
				]
				
		"COMPLETED":
			dialogue_lines = [
				"Api unggunku sudah menyala dengan hangat.",
				"Terima kasih sekali lagi atas bantuanmu!"
			]

func end_dialogue() -> void:
	is_chatting = false
	dialogue_ui.visible = false
	
	# TAMBAHKAN BLOK INI:
	if should_complete_quest_on_end:
		should_complete_quest_on_end = false
		trigger_campfire_cutscene()
		return
		
	if should_start_quest_on_end:
		QuestManager.start_quest("collect_wood")
		should_start_quest_on_end = false
	
	if is_player_in_chat_zone and interact_icon:
		interact_icon.visible = true
		start_hover_animation()

func start_dialogue() -> void:
	is_chatting = true
	current_line_index = 0
	
	if interact_icon:
		interact_icon.visible = false
		stop_hover_animation()
		
	prepare_dialogue_lines() # Tentukan isi percakapan sebelum dialog tampil
	dialogue_ui.visible = true
	show_current_line()

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

func _on_chat_detection_body_entered(body: Node2D) -> void:
	print("Body masuk area: ", body.name) # Tambahkan ini untuk cek di Output
	if body is Player:
		is_player_in_chat_zone = true
		if interact_icon and not is_chatting:
			interact_icon.visible = true
			start_hover_animation()

func _on_chat_detection_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_in_chat_zone = false
		if interact_icon:
			interact_icon.visible = false
			stop_hover_animation()
		
		# Jika player jalan menjauh saat sedang chatting, tutup dialognya tanpa memulai quest
		if is_chatting:
			is_chatting = false
			dialogue_ui.visible = false
			should_start_quest_on_end = false # Reset agar quest tidak langsung mulai jika ditinggal pergi

func start_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_loops()
	tween.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()

func trigger_campfire_cutscene() -> void:
	# 1. Hapus 4 kayu dari inventory
	GameManager.remove_item("wood", 4)
	
	# 2. Fade Out (Layar pelan-pelan jadi hitam)
	await SceneTransition.fade_out()
	
	# 3. Tampikan api unggun & update QuestManager saat layar hitam
	if campfire:
		campfire.visible = true
	QuestManager.complete_quest("collect_wood")
	
	# Jeda layar hitam sebentar
	await get_tree().create_timer(0.3).timeout
	
	# 4. Fade In (Layar kembali terang)
	await SceneTransition.fade_in()
	
	if is_player_in_chat_zone and interact_icon:
		interact_icon.visible = true
		start_hover_animation()
