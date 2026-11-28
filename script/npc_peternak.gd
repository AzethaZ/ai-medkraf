extends CharacterBody2D

@export var farm_chick_scene: PackedScene
@export var farm_cutscene_texture: Texture2D
@export_file("*.tscn") var next_world_scene_path: String = "res://scene/World/world_langit_2.tscn"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var chat_detection: Area2D = $chat_detection if has_node("chat_detection") else null
@onready var cutscene_trigger: Area2D = $CutsceneTrigger if has_node("CutsceneTrigger") else null
@onready var interact_icon: Sprite2D = $InteractIcon if has_node("InteractIcon") else null
@onready var cutscene_pivot_peternak: Node2D = $CutscenePivotPeternak if has_node("CutscenePivotPeternak") else null
@onready var cutscene_pivot_danum: Node2D = $CutscenePivotDanum if has_node("CutscenePivotDanum") else null

@onready var dialogue_ui: Control = $DialogueUI if has_node("DialogueUI") else null
@onready var dialogue_box: PanelContainer = $DialogueUI/PanelContainer if has_node("DialogueUI/PanelContainer") else null
@onready var dialogue_label: Label = $DialogueUI/PanelContainer/VBoxContainer/Label if has_node("DialogueUI/PanelContainer/VBoxContainer/Label") else null

var should_complete_quest_on_end: bool = false
var should_start_quest_on_end: bool = false
var current_active_quest: String = ""

var is_player_in_chat_zone: bool = false
var is_chatting: bool = false
var is_ending_cutscene_running: bool = false
var current_line_index: int = 0
var dialogue_lines: Array[String] = []
var tween: Tween
var text_tween: Tween

func _ready() -> void:
	if dialogue_ui:
		dialogue_ui.visible = false
	if interact_icon:
		interact_icon.visible = false
		
	if QuestManager and QuestManager.get_quest_status("quest_ayam_1") == "COMPLETED":
		spawn_farm_chicks()
		
	if chat_detection:
		if not chat_detection.body_entered.is_connected(_on_chat_detection_body_entered):
			chat_detection.body_entered.connect(_on_chat_detection_body_entered)
		if not chat_detection.body_exited.is_connected(_on_chat_detection_body_exited):
			chat_detection.body_exited.connect(_on_chat_detection_body_exited)
			
	if cutscene_trigger:
		if not cutscene_trigger.body_entered.is_connected(_on_cutscene_trigger_body_entered):
			cutscene_trigger.body_entered.connect(_on_cutscene_trigger_body_entered)

func _unhandled_input(event: InputEvent) -> void:
	if is_chatting or is_ending_cutscene_running:
		return
	if DialogueManager and "is_active" in DialogueManager and DialogueManager.is_active:
		return
		
	if QuestManager and QuestManager.get_quest_status("quest_ayam_3") == "READY_TO_SUBMIT":
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
			"Tolong! Anak-anak ayamku lepas sampai ke area sekitar desa!",
			"Bisa tolong kumpulkan 3 anak ayam dan bawa kembali ke sini?"
		]
		
	elif q1_status == "ACTIVE" or q1_status == "READY_TO_SUBMIT":
		if q1_count >= 3 or q1_status == "READY_TO_SUBMIT":
			current_active_quest = "quest_ayam_1"
			should_complete_quest_on_end = true
			dialogue_lines = [
				"Terima kasih banyak atas bantuanmu, nak! Anak-anak ayam sudah kembali aman.",
				"Tapi ada masalah lain! Ayam jago galakku kabur sampai ke area hutan bambu!",
				"Pergi ke arah gerbang besar merah, dia suka berlatih disana. Tolong bantu tangkap dia ya!"
			]
		else:
			dialogue_lines = [
				"Kamu baru menemukan " + str(q1_count) + "/3 anak ayam...",
				"Coba cari lagi di area sebelah kiri!"
			]
			
	# --- TAHAP 2: QUEST AYAM JAGO GALAK ---
	elif q3_status == "ACTIVE" or q3_status == "READY_TO_SUBMIT":
		var q3_count = QuestManager.get_quest_progress("quest_ayam_3") if QuestManager else 0
		if q3_count >= 1 or q3_status == "READY_TO_SUBMIT":
			current_active_quest = "quest_ayam_3"
			should_complete_quest_on_end = true
			dialogue_lines = []
		else:
			dialogue_lines = [
				"Ayam jago galak itu masih berkeliaran di hutan bambu!",
				"Hati-hati ya Danum, patukannya lumayan sakit!"
			]
			
	elif q3_status == "COMPLETED":
		dialogue_lines = [
			"Semua ayam sudah aman di kandang. Terima kasih banyak atas bantuanmu, nak!"
		]

func start_dialogue() -> void:
	if is_chatting or is_ending_cutscene_running:
		return
	is_chatting = true
	if interact_icon:
		interact_icon.visible = false
		stop_hover_animation()
		
	prepare_dialogue_lines()
	
	if current_active_quest == "quest_ayam_3" and should_complete_quest_on_end:
		await _play_quest_3_ending_cutscene()
		return
	
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

func _on_cutscene_trigger_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player") or body.name.begins_with("Player"):
		if QuestManager and QuestManager.get_quest_status("quest_ayam_3") == "READY_TO_SUBMIT":
			if not is_chatting and not is_ending_cutscene_running:
				current_active_quest = "quest_ayam_3"
				should_complete_quest_on_end = true
				_play_quest_3_ending_cutscene()

func _play_quest_3_ending_cutscene() -> void:
	if is_ending_cutscene_running:
		return
	is_ending_cutscene_running = true
	is_chatting = true
	if interact_icon:
		interact_icon.visible = false
		stop_hover_animation()
		
	var player_node: Node2D = get_tree().current_scene.find_child("Player", true, false) as Node2D
	if player_node:
		if player_node.has_method("disable_movement"):
			player_node.disable_movement()
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
			
	var cam: Camera2D = get_viewport().get_camera_2d()
	
	var danum_pivot: Node2D = player_node
	if player_node and player_node.has_node("DialoguePivot"):
		danum_pivot = player_node.get_node("DialoguePivot") as Node2D
		
	var peternak_pivot: Node2D = self
	if has_node("DialoguePivot"):
		peternak_pivot = get_node("DialoguePivot") as Node2D
		
	var cam_move_duration: float = 1.6
	var prev_smoothing: bool = false
	var mc_cam_pos: Vector2 = Vector2.ZERO
	
	# --- BAGIAN 1: KE NPC (DIALOG 1) -> KE MC (DIALOG 2) -> KE NPC (DIALOG 3) ---
	if cam and player_node:
		prev_smoothing = cam.position_smoothing_enabled
		cam.position_smoothing_enabled = false
		
		mc_cam_pos = cam.global_position
		var npc_cam_pos := Vector2(global_position.x, mc_cam_pos.y)
		
		# 1. Geser kamera pelan ke NPC -> NPC ngomong (Dialog 1)
		var cam_to_npc_1 := create_tween()
		cam_to_npc_1.tween_property(cam, "global_position", npc_cam_pos, cam_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await cam_to_npc_1.finished
		
		await _say_line("Akhirnya selesai juga! Terima kasih banyak sudah membantuku. Sekarang ayam-ayam itu bisa kembali berkeliaran dengan aman.", peternak_pivot)
		
		# 2. Kamera pindah ke MC -> MC ngomong (Dialog 2)
		var cam_to_mc := create_tween()
		cam_to_mc.tween_property(cam, "global_position", mc_cam_pos, cam_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await cam_to_mc.finished
		
		await _say_line("Senang bisa membantu! Tapi kenapa kalian memilih memelihara ayam di tengah hutan?", danum_pivot)
		
		# 3. Kamera pindah lagi ke NPC -> NPC ngomong (Dialog 3)
		var cam_to_npc_2 := create_tween()
		cam_to_npc_2.tween_property(cam, "global_position", npc_cam_pos, cam_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await cam_to_npc_2.finished
		
		await _say_line("Karena hutan menyediakan ruang bagi ayam untuk berkeliaran dan mencari makanan. Kami juga mendapatkan penghasilan dari telur dan ayam yang kami jual.", peternak_pivot)
	else:
		await _say_line("Akhirnya selesai juga! Terima kasih banyak sudah membantuku. Sekarang ayam-ayam itu bisa kembali berkeliaran dengan aman.", peternak_pivot)
		await _say_line("Senang bisa membantu! Tapi kenapa kalian memilih memelihara ayam di tengah hutan?", danum_pivot)
		await _say_line("Karena hutan menyediakan ruang bagi ayam untuk berkeliaran dan mencari makanan. Kami juga mendapatkan penghasilan dari telur dan ayam yang kami jual.", peternak_pivot)
		
	# --- BAGIAN 2: TRANSISI MASUK KE GAMBAR CUTSCENE (KAMERA TETAP DI NPC) ---
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		
	var cutscene_layer := CanvasLayer.new()
	cutscene_layer.layer = 10
	
	var bg_rect := ColorRect.new()
	bg_rect.color = Color.BLACK
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene_layer.add_child(bg_rect)
	
	var img_rect := TextureRect.new()
	img_rect.texture = farm_cutscene_texture
	img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene_layer.add_child(img_rect)
	add_child(cutscene_layer)
	
	var cs_peternak_pivot: Node2D = cutscene_pivot_peternak if is_instance_valid(cutscene_pivot_peternak) else peternak_pivot
	var cs_danum_pivot: Node2D = cutscene_pivot_danum if is_instance_valid(cutscene_pivot_danum) else danum_pivot
	
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()
		
	# --- BAGIAN 3: DIALOG DI DALAM GAMBAR CUTSCENE (DIALOG 4 - 7) ---
	var in_cutscene_dialogues = [
		{"speaker": cs_danum_pivot, "text": "Jadi, kalian bisa memanfaatkan hutan untuk beternak tanpa harus menebang banyak pohon?"},
		{"speaker": cs_peternak_pivot, "text": "Tentu saja. Selama kita tahu batasnya dan menjaga lingkungan sekitar, hutan bisa memberikan banyak manfaat bagi kehidupan kita."},
		{"speaker": cs_danum_pivot, "text": "Oh! bagus ya, tidak seperti di tempatku! Berarti kita juga harus menjaga tempat yang memberi kita kehidupan."},
		{"speaker": cs_peternak_pivot, "text": "Betul sekali. Hutan bukan hanya tempat tinggal bagi hewan, tetapi juga sumber kehidupan bagi manusia."}
	]
	
	for entry in in_cutscene_dialogues:
		await _say_line(entry["text"], entry["speaker"])
		
	# --- BAGIAN 4: KEMBALI KE VIEW GAMEPLAY BIASA (BARU KAMERA KEMBALI KE MC) ---
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		
	if is_instance_valid(cutscene_layer):
		cutscene_layer.queue_free()
		
	if cam and player_node:
		cam.global_position = mc_cam_pos
		cam.position_smoothing_enabled = prev_smoothing
		
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()
		
	# --- BAGIAN 5: DANUM BERTERIMA KASIH & LANGSUNG MASUK WORLD_LANGIT_2 ---
	await _say_line("Terima kasih atas penjelasannya, Apui! Aku akan melanjutkan perjalananku.", danum_pivot)
	
	if QuestManager:
		QuestManager.complete_quest("quest_ayam_3", true)
	should_complete_quest_on_end = false
	
	if SceneTransition and SceneTransition.has_method("fade_out"):
		await SceneTransition.fade_out()
		
	_play_enggang_wing_sfx()
	await get_tree().create_timer(0.8, true).timeout
	_play_enggang_wing_sfx()
	await get_tree().create_timer(0.8, true).timeout
	
	if player_node and player_node.has_method("enable_movement"):
		player_node.enable_movement()
		
	get_tree().paused = false
	if next_world_scene_path != "" and ResourceLoader.exists(next_world_scene_path):
		get_tree().change_scene_to_file(next_world_scene_path)

func _say_line(text: String, target_node: Node2D) -> void:
	if not is_instance_valid(target_node):
		target_node = self
	if DialogueManager and DialogueManager.has_method("start_dialogue"):
		await DialogueManager.start_dialogue([text], target_node)
		if DialogueManager.has_signal("dialogue_finished"):
			await DialogueManager.dialogue_finished
		elif DialogueManager.has_signal("dialogue_ended"):
			await DialogueManager.dialogue_ended

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

	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		if player.has_method("set_dialogue_state"):
			player.set_dialogue_state(false)
		elif player.has_method("enable_movement"):
			player.enable_movement()
		player.set_physics_process(true)

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
				QuestManager.complete_quest("quest_ayam_1", true)
				spawn_farm_chicks()
				
			if QuestManager:
				QuestManager.start_quest("quest_ayam_3")
				
			await get_tree().create_timer(0.3).timeout
			
			if SceneTransition and SceneTransition.has_method("fade_in"):
				await SceneTransition.fade_in()
		else:
			if QuestManager:
				QuestManager.complete_quest(current_active_quest, true)
				
		should_complete_quest_on_end = false
		
	is_chatting = false
	if is_player_in_chat_zone and interact_icon and not is_ending_cutscene_running:
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
		if interact_icon and not is_chatting and not is_ending_cutscene_running:
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

func _play_enggang_wing_sfx() -> void:
	var wing_path := "res://assets/audio/wing_sound.mp3"
	if not ResourceLoader.exists(wing_path):
		return
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = load(wing_path)
	sfx_player.pitch_scale = randf_range(0.95, 1.05)
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)
