extends CharacterBody2D

@export var auto_walk_speed: float = 120.0
@export var auto_walk_duration: float = 1.0
@export var stop_distance_x: float = 95.0
@export var camera_pan_duration: float = 0.65
# Seberapa jauh kamera menggeser ke kiri agar fokus ke NPC (nilai negatif = ke kiri)
@export var camera_pan_left_offset: float = -180.0
@export var npc_intro_line: String = "Wah, sepertinya ada tamu baru yang datang berkunjung ke kebun ini."

@onready var interact_icon: Node2D = $InteractIcon if has_node("InteractIcon") else null
@onready var chat_detection: Area2D = $chat_detection if has_node("chat_detection") else null
@onready var cutscene_trigger: Area2D = $CutsceneTrigger if has_node("CutsceneTrigger") else null
@onready var dialogue_pivot: Marker2D = $DialoguePivot if has_node("DialoguePivot") else null
@onready var npc_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

# Referensi Node UI Pilihan Ganda (ChoicePanel)
@onready var quiz_ui: CanvasLayer = $QuizUI if has_node("QuizUI") else null
@onready var question_label: Label = $QuizUI/QuestionLabel if has_node("QuizUI/QuestionLabel") else null
@onready var option_a: Button = $QuizUI/ChoicePanel/VBoxContainer/OptionA if has_node("QuizUI/ChoicePanel/VBoxContainer/OptionA") else null
@onready var option_b: Button = $QuizUI/ChoicePanel/VBoxContainer/OptionB if has_node("QuizUI/ChoicePanel/VBoxContainer/OptionB") else null
@onready var option_c: Button = $QuizUI/ChoicePanel/VBoxContainer/OptionC if has_node("QuizUI/ChoicePanel/VBoxContainer/OptionC") else null
@onready var cursor_arrow: Control = $QuizUI/CursorArrow if has_node("QuizUI/CursorArrow") else null

@export var quiz_focus_zoom: Vector2 = Vector2(1.45, 1.45) # Tingkat zoom mendekat ke NPC
@export var quiz_focus_offset: Vector2 = Vector2(0.0, -60.0) # Geseran posisi kamera ke tubuh NPC
@export var quiz_fade_duration: float = 0.5

@export_group("Ending Cutscene Image & Pivots")
@export var ending_cutscene_image: Texture2D # Drag gambar ilustrasi cutscene ke sini di Inspector!
@export var cutscene_mc_screen_pos: Vector2 = Vector2(180.0, 220.0)  # Posisi bubble dialog MC di atas gambar (layar 640x360)
@export var cutscene_npc_screen_pos: Vector2 = Vector2(460.0, 200.0) # Posisi bubble dialog NPC di atas gambar (layar 640x360)

var _orig_cam_pos: Vector2
var _orig_cam_zoom: Vector2
var _orig_cam_top_level: bool
var _fade_overlay: CanvasLayer
var _fade_rect: ColorRect

var player_in_range: bool = false
var player_ref: Node2D = null
var hover_tween: Tween = null
var is_talking: bool = false
var cutscene_triggered: bool = false

# Variabel navigasi pilihan ganda
var is_choosing: bool = false
var current_cursor_index: int = 0
var selected_choice: int = -1
var current_display_texts: Array[String] = []

func _ready() -> void:
	if interact_icon:
		interact_icon.visible = false
	if quiz_ui:
		quiz_ui.visible = false

	for opt in [option_a, option_b, option_c]:
		if opt:
			opt.focus_mode = Control.FOCUS_NONE
			opt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if chat_detection:
		chat_detection.body_entered.connect(_on_chat_detection_body_entered)
		chat_detection.body_exited.connect(_on_chat_detection_body_exited)

	if cutscene_trigger:
		cutscene_trigger.body_entered.connect(_on_cutscene_trigger_entered)

func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name.to_lower().contains("player") or body is CharacterBody2D

func _find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found:
			return found
	return null

# --- TRIGGER CUTSCENE SAAT MENYENTUH COLLISION ---
func _on_cutscene_trigger_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if cutscene_triggered or is_talking:
		return
	if GameState.get("vietnam_quest_started") == true or GameState.get("vietnam_quest_completed") == true:
		return

	cutscene_triggered = true
	player_ref = body
	_start_npc_intro_cutscene(body)

func _start_npc_intro_cutscene(player: Node2D) -> void:
	is_talking = true
	if interact_icon:
		interact_icon.visible = false
		_stop_hover_tween()

	if player.has_method("disable_movement"):
		player.disable_movement()
	elif "can_move" in player:
		player.can_move = false

	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	var target_npc: Node2D = _get_npc_pivot()
	var player_cam: Camera2D = _find_camera(player)
	var orig_offset_x: float = 0.0

	# 1. Geser kamera ke kiri menyorot NPC & tahan kamera tetap diam di sana
	if player_cam:
		orig_offset_x = player_cam.offset.x
		var pan_left := create_tween()
		pan_left.tween_property(player_cam, "offset:x", orig_offset_x + camera_pan_left_offset, camera_pan_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await pan_left.finished

	# 2. Pak Petani menghadap arah player & mengucapkan 1 kalimat pembuka
	var face_player_dir: float = sign(player.global_position.x - global_position.x)
	if npc_sprite and face_player_dir != 0:
		npc_sprite.flip_h = (face_player_dir < 0)

	if DialogueManager and npc_intro_line != "":
		await _say([npc_intro_line], target_npc)

	# 3. MC berjalan masuk ke kiri mendekati NPC sampai jarak stop_distance_x
	var walk_dir: float = sign(global_position.x - player.global_position.x)
	if walk_dir == 0:
		walk_dir = -1.0

	# Matikan _physics_process player agar tidak terpotong "if not can_move: return" di player.gd
	player.set_physics_process(false)

	var player_anim: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if is_instance_valid(player_anim):
		player_anim.flip_h = (walk_dir < 0)
	if player.has_method("play_cutscene_walk"):
		player.play_cutscene_walk()
	elif is_instance_valid(player_anim):
		player_anim.play("walk")

	var elapsed: float = 0.0
	while is_instance_valid(player) and elapsed < auto_walk_duration:
		if abs(global_position.x - player.global_position.x) <= stop_distance_x:
			break

		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		var prev_player_x: float = player.global_position.x

		# Gerakkan player langsung ke arah NPC
		if player is CharacterBody2D:
			player.velocity = Vector2(walk_dir * auto_walk_speed, 0.0)
			player.move_and_slide()
		else:
			player.global_position.x += walk_dir * auto_walk_speed * delta

		# Kompensasi offset kamera sebesar perpindahan player agar layar kamera tetap diam di NPC
		if player_cam and is_instance_valid(player):
			var moved_dx: float = player.global_position.x - prev_player_x
			player_cam.offset.x -= moved_dx

		await get_tree().physics_frame

	# 4. Hentikan langkah MC & kembalikan ke animasi "default"
	if is_instance_valid(player):
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		if player.has_method("play_cutscene_idle"):
			player.play_cutscene_idle()
		elif is_instance_valid(player_anim):
			player_anim.play("default")

		var face_npc_dir: float = sign(global_position.x - player.global_position.x)
		if is_instance_valid(player_anim) and face_npc_dir != 0:
			player_anim.flip_h = (face_npc_dir < 0)

		player.set_physics_process(true)

	# 5. Lanjut ke dialog utama (kamera tetap menyorot NPC & MC)
	await _play_initial_dialogue(player)

	# 6. Setelah dialog selesai, kembalikan offset kamera mulus ke MC
	if player_cam:
		var pan_back := create_tween()
		pan_back.tween_property(player_cam, "offset:x", orig_offset_x, camera_pan_duration * 0.8)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await pan_back.finished

	if is_instance_valid(player):
		if player.has_method("enable_movement"):
			player.enable_movement()
		elif "can_move" in player:
			player.can_move = true

	is_talking = false
	if player_in_range and interact_icon:
		interact_icon.visible = true
		_start_hover_tween()

func _on_chat_detection_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = true
		player_ref = body
		if interact_icon and not is_talking:
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
	if is_choosing:
		if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W):
			current_cursor_index = (current_cursor_index - 1 + 3) % 3
			_update_choice_visuals()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S):
			current_cursor_index = (current_cursor_index + 1) % 3
			_update_choice_visuals()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			selected_choice = current_cursor_index
			get_viewport().set_input_as_handled()
		return

	if is_talking:
		return

	if player_in_range and event.is_action_pressed("interact"):
		if DialogueManager and "is_active" in DialogueManager and DialogueManager.is_active:
			return
		_handle_interaction()

func _update_choice_visuals() -> void:
	var options: Array[Button] = [option_a, option_b, option_c]
	for i in range(options.size()):
		var btn := options[i]
		if btn and i < current_display_texts.size():
			btn.text = current_display_texts[i]
			var is_selected: bool = (i == current_cursor_index)
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_selected else Color(0.85, 0.85, 0.85, 1.0)

			if is_selected and cursor_arrow:
				var btn_rect: Rect2 = btn.get_global_rect()
				cursor_arrow.global_position = Vector2(
					btn_rect.position.x - cursor_arrow.size.x - 4.0,
					btn_rect.position.y + (btn_rect.size.y - cursor_arrow.size.y) / 2.0
				)

func _get_npc_pivot() -> Node2D:
	if is_instance_valid(dialogue_pivot):
		return dialogue_pivot
	return self

func _get_player_node() -> Node2D:
	if is_instance_valid(player_ref):
		return player_ref
	var p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p):
		return p
	if get_parent() and get_parent().has_node("Player"):
		return get_parent().get_node("Player")
	return null

func _get_player_dialogue_pivot(player: Node2D) -> Node2D:
	if not is_instance_valid(player):
		return _get_npc_pivot()

	if player.has_node("DialoguePivot"):
		return player.get_node("DialoguePivot")

	var temp_pivot := Marker2D.new()
	temp_pivot.name = "DialoguePivot"
	temp_pivot.position = Vector2(0, -45)
	player.add_child(temp_pivot)
	return temp_pivot

func _handle_interaction() -> void:
	if not DialogueManager:
		return

	is_talking = true
	if interact_icon:
		interact_icon.visible = false
		_stop_hover_tween()

	var player: Node2D = _get_player_node()
	if player and "can_move" in player:
		player.can_move = false

	if GameState.vietnam_quest_completed:
		await _play_post_quest_dialogue()
	elif GameState.vietnam_clue_tree_found and GameState.vietnam_clue_leaves_found:
		await _play_quiz_and_ending(player)
	elif GameState.vietnam_quest_started:
		await _play_reminder_dialogue()
	else:
		await _play_initial_dialogue(player)

	if player and "can_move" in player:
		player.can_move = true

	is_talking = false
	if player_in_range and interact_icon:
		interact_icon.visible = true
		_start_hover_tween()

# --- TAHAP 1: DIALOG AWAL ---
func _play_initial_dialogue(player: Node2D) -> void:
	var target_npc: Node2D = _get_npc_pivot()
	var target_player: Node2D = _get_player_dialogue_pivot(player)

	await _say([
		"Wah, kebun ini terlihat berbeda.",
		"Kenapa tanaman kopi di sini dikelilingi banyak pohon?"
	], target_player)

	await _say([
		"Karena kami menggunakan sistem yang disebut agroforestri.",
		"Kami menggabungkan tanaman pertanian dengan pepohonan agar bisa saling memberi manfaat."
	], target_npc)

	await _say([
		"Menarik sekali!",
		"Tapi bagaimana cara kalian tahu tanaman apa yang harus ditanam bersama?"
	], target_player)

	await _say([
		"Haha, itu perlu dipelajari.",
		"Kalau kamu mau, aku punya beberapa pertanyaan untukmu."
	], target_npc)

	await _say([
		"Pertanyaan?",
		"Memangnya aku sedang mengikuti ujian?"
	], target_player)

	await _say([
		"Hahaha! Tidak perlu khawatir, jawabannya ada di sekitar kebun ini.",
		"Coba amati baik-baik, mungkin kamu bisa menemukan jawabannya sendiri."
	], target_npc)

	await _say(["Baiklah! Aku akan mencarinya."], target_player)

	GameState.vietnam_quest_started = true
	if QuestManager and QuestManager.has_method("start_quest"):
		QuestManager.start_quest("quest_kopi_1")

# --- DIALOG SAAT BELUM MENEMUKAN SEMUA PETUNJUK ---
func _play_reminder_dialogue() -> void:
	var target_npc: Node2D = _get_npc_pivot()
	var found_count: int = int(GameState.vietnam_clue_tree_found) + int(GameState.vietnam_clue_leaves_found)

	await _say([
		"Sudah menemukan jawabannya? Petunjuk terkumpul: %d/2." % found_count,
		"Coba periksa pohon-pohon besar di sekitar sini dan area kebun di sebelah sana!"
	], target_npc)

# --- TAHAP 2 & 3: KUIS PILIHAN GANDA ---
# TAHAP 2 & 3: KUIS PILIHAN GANDA
# TAHAP 2 & 3: KUIS PILIHAN GANDA
func _play_quiz_and_ending(player: Node2D) -> void:
	var target_npc: Node2D = _get_npc_pivot()
	var target_player: Node2D = _get_player_dialogue_pivot(player)

	# 1. Dialog pembuka dulu sebelum kamera zoom-in
	await _say([
		"Wah, kamu sudah menemukan kedua petunjuknya!",
		"Sekarang coba jawab beberapa pertanyaanku untuk menguji pemahamanmu."
	], target_npc)

	# 2. Baru setelah dialog selesai, fade layar & zoom kamera mendekat ke NPC
	await _fade_and_zoom_to_npc()

	var is_correct_1: bool = await _ask_multiple_choice(
		[
			"Coba perhatikan tanaman kopi di sekitar sini.",
			"Menurutmu, apa manfaat pohon-pohon besar yang tumbuh di antara tanaman kopi?"
		],
		"Manfaat pohon besar di antara kopi?",
		[
			{"text": "Menghalangi seluruh sinar matahari", "correct": false},
			{"text": "Melindungi tanaman kopi dari panas matahari", "correct": true},
			{"text": "Menggantikan kebutuhan air tanaman kopi", "correct": false}
		],
		target_npc
	)

	if is_correct_1:
		await _say([
			"Benar!",
			"Pohon besar melindungi tanaman kopi dari sinar matahari langsung sehingga tanaman bisa tumbuh dengan baik."
		], target_npc)
	else:
		await _say([
			"Hmm, kurang tepat.",
			"Coba ingat kembali catatan di dekat pohon besar tadi, lalu bicara lagi denganku kalau sudah siap!"
		], target_npc)
		await _fade_and_reset_camera()
		return

	var is_correct_2: bool = await _ask_multiple_choice(
		[
			"Pertanyaan kedua.",
			"Apa manfaat daun kering yang diletakkan di sekitar tanaman?"
		],
		"Manfaat daun kering di sekitar tanaman?",
		[
			{"text": "Membantu menjaga kelembapan tanah", "correct": true},
			{"text": "Membuat tanaman tidak membutuhkan sinar matahari", "correct": false},
			{"text": "Menghentikan pertumbuhan seluruh tanaman lain", "correct": false}
		],
		target_npc
	)

	if is_correct_2:
		await _say(["Wah, ternyata kamu berhasil menemukan semua jawabannya!"], target_npc)
	else:
		await _say([
			"Bukan itu.",
			"Coba ingat kembali catatan di bawah tumpukan daun kering tadi, lalu ajak aku bicara lagi!"
		], target_npc)
		await _fade_and_reset_camera()
		return

	await _say([
		"Hehe, ternyata jawabannya ada di sekitar kebun ini.",
		"Aku baru tahu kalau setiap bagian pohon punya manfaat yang berbeda."
	], target_player)

	# --- MULAI TRANSISI CUTSCENE GAMBAR + 2 PIVOT DIALOG ---
	var cs_pivots: Dictionary = await _enter_ending_cutscene(player)
	var cs_npc: Node2D = cs_pivots["npc"]
	var cs_mc: Node2D = cs_pivots["mc"]

	await _say([
		"Benar. Kami tidak hanya menanam tanaman untuk dipanen,",
		"tetapi juga memperhatikan bagaimana tanaman-tanaman itu bisa saling mendukung."
	], cs_npc)

	await _say([
		"Jadi, dengan menanam berbagai jenis tanaman bersama-sama,",
		"kalian bisa mendapatkan hasil panen sekaligus menjaga kondisi kebun?"
	], cs_mc)

	await _say([
		"Tepat sekali! Itulah inti dari sistem agroforestri.",
		"Kami bisa memperoleh manfaat lahan tanpa menghilangkan semua pepohonan."
	], cs_npc)

	await _say([
		"Aku mulai mengerti.",
		"Ternyata menjaga alam juga bisa dimulai dari cara kita mengelola lahan."
	], cs_mc)

	await _say(["Haha, sepertinya kamu anak yang cepat belajar."], cs_npc)

	# --- KELUAR CUTSCENE GAMBAR & KEMBALI KE MAP NORMAL ---
	await _exit_ending_cutscene()

	# Dialog penutup kembali memakai pivot karakter asli di map (target_player & target_npc)
	await _say([
		"Hehe, oh iya aku akan segera melanjutkan perjalananku.",
		"Terimakasih atas pelajarannya pak petani perjalanan di sini sangat menyenangkan!"
	], target_player)

	await _say([
		"Sama-sama,",
		"Semoga perjalananmu berikutnya juga menyenangkan!"
	], target_npc)

	GameState.vietnam_quest_completed = true
	if QuestManager and QuestManager.has_method("complete_quest"):
		QuestManager.complete_quest("quest_kopi_1", true)

	# --- KELUAR CUTSCENE GAMBAR & KEMBALIKAN KAMERA KE PLAYER ---
	await _exit_ending_cutscene()

func _play_post_quest_dialogue() -> void:
	var target_npc: Node2D = _get_npc_pivot()
	await _say([
		"Terima kasih sudah berkunjung ke kebun kami, Danum.",
		"Semoga perjalananmu berikutnya menyenangkan!"
	], target_npc)

func _say(lines: Array[String], pivot: Node2D) -> void:
	DialogueManager.start_dialogue(lines, pivot)
	if "is_active" in DialogueManager:
		while DialogueManager.is_active:
			await get_tree().process_frame
	elif DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	elif DialogueManager.has_signal("dialogue_ended"):
		await DialogueManager.dialogue_ended

func _ask_multiple_choice(question_lines: Array[String], short_title: String, raw_options: Array[Dictionary], pivot: Node2D) -> bool:
	await _say(question_lines, pivot)
	await get_tree().process_frame
	quiz_ui.visible = true
	await _animate_quiz_paper_in()

	if question_label:
		question_label.text = short_title

	var shuffled_options: Array[Dictionary] = raw_options.duplicate()
	shuffled_options.shuffle()

	current_display_texts = [
		"A. " + shuffled_options[0]["text"],
		"B. " + shuffled_options[1]["text"],
		"C. " + shuffled_options[2]["text"]
	]

	current_cursor_index = 0
	selected_choice = -1
	is_choosing = true

	if quiz_ui:
		quiz_ui.visible = true

	await get_tree().process_frame
	_update_choice_visuals()

	while selected_choice == -1:
		await get_tree().process_frame

	is_choosing = false
	if quiz_ui:
		quiz_ui.visible = false

	return shuffled_options[selected_choice]["correct"]

func _fade_and_zoom_to_npc() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if not cam:
		return

	# Simpan posisi & zoom kamera sebelumnya
	_orig_cam_pos = cam.global_position
	_orig_cam_zoom = cam.zoom
	_orig_cam_top_level = cam.top_level

	# 1. Fade layar ke hitam
	await _run_screen_fade(1.0, quiz_fade_duration)

	# 2. Pindahkan & zoom kamera lebih dekat ke NPC Petani
	cam.top_level = true
	cam.global_position = global_position + quiz_focus_offset
	cam.zoom = quiz_focus_zoom

	# 3. Fade layar kembali terang
	await _run_screen_fade(0.0, quiz_fade_duration)

func _fade_and_reset_camera() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if not cam:
		return

	await _run_screen_fade(1.0, quiz_fade_duration)

	cam.top_level = _orig_cam_top_level
	cam.zoom = _orig_cam_zoom
	cam.global_position = _orig_cam_pos

	await _run_screen_fade(0.0, quiz_fade_duration)

func _run_screen_fade(target_alpha: float, duration: float) -> void:
	if not _fade_overlay or not is_instance_valid(_fade_overlay):
		_fade_overlay = CanvasLayer.new()
		_fade_overlay.layer = 50
		_fade_rect = ColorRect.new()
		_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_overlay.add_child(_fade_rect)
		add_child(_fade_overlay)

	var t := create_tween()
	t.tween_property(_fade_rect, "color:a", target_alpha, duration).set_trans(Tween.TRANS_SINE)
	await t.finished

var _quiz_dim_rect: ColorRect

func _animate_quiz_paper_in() -> void:
	var choice_panel: Control = quiz_ui.find_child("ChoicePanel", true, false) as Control
	var targets: Array[Control] = []
	if question_label:
		targets.append(question_label)
	if choice_panel:
		targets.append(choice_panel)

	# Buat latar belakang hitam transparan di dalam QuizUI (paling belakang)
	if not _quiz_dim_rect or not is_instance_valid(_quiz_dim_rect):
		_quiz_dim_rect = ColorRect.new()
		_quiz_dim_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		_quiz_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_quiz_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quiz_ui.add_child(_quiz_dim_rect)
		quiz_ui.move_child(_quiz_dim_rect, 0) # Taruh di urutan paling belakang agar tidak menutupi tombol

	# Set transparan di awal
	_quiz_dim_rect.color.a = 0.0
	for ctrl in targets:
		ctrl.modulate.a = 0.0

	# Fade-in layar gelap + teks/tombol secara halus
	var t := create_tween().set_parallel(true)
	t.tween_property(_quiz_dim_rect, "color:a", 0.55, 0.35).set_trans(Tween.TRANS_SINE) # 0.55 = gelap setengah (ubah ke 0.85 jika ingin lebih pekat)
	for ctrl in targets:
		t.tween_property(ctrl, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	await t.finished

func _animate_quiz_paper_out() -> void:
	var choice_panel: Control = quiz_ui.find_child("ChoicePanel", true, false) as Control
	var targets: Array[Control] = []
	if question_label:
		targets.append(question_label)
	if choice_panel:
		targets.append(choice_panel)

	var t := create_tween().set_parallel(true)
	if _quiz_dim_rect and is_instance_valid(_quiz_dim_rect):
		t.tween_property(_quiz_dim_rect, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	for ctrl in targets:
		t.tween_property(ctrl, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	await t.finished

	quiz_ui.visible = false
	for ctrl in targets:
		ctrl.modulate.a = 1.0

var _cutscene_layer: CanvasLayer
var _cutscene_tex_rect: TextureRect
var _cutscene_mc_marker: Node2D
var _cutscene_npc_marker: Node2D

func _enter_ending_cutscene(_player: Node2D) -> Dictionary:
	# 1. Fade layar ke hitam
	await _run_screen_fade(1.0, quiz_fade_duration)

	# 2. Tutup QuizUI & latar gelap kuis
	if quiz_ui:
		quiz_ui.visible = false
	if _quiz_dim_rect and is_instance_valid(_quiz_dim_rect):
		_quiz_dim_rect.color.a = 0.0

	# 3. Buat CanvasLayer gambar cutscene fullscreen
	if not _cutscene_layer or not is_instance_valid(_cutscene_layer):
		_cutscene_layer = CanvasLayer.new()
		_cutscene_layer.layer = 40
		add_child(_cutscene_layer)

		_cutscene_tex_rect = TextureRect.new()
		_cutscene_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cutscene_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cutscene_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_cutscene_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cutscene_layer.add_child(_cutscene_tex_rect)

	if ending_cutscene_image:
		_cutscene_tex_rect.texture = ending_cutscene_image
	_cutscene_layer.visible = true

	# 4. Siapkan 2 pivot khusus untuk posisi dialog MC & NPC di atas gambar cutscene
	if not _cutscene_mc_marker or not is_instance_valid(_cutscene_mc_marker):
		_cutscene_mc_marker = Node2D.new()
		add_child(_cutscene_mc_marker)
	if not _cutscene_npc_marker or not is_instance_valid(_cutscene_npc_marker):
		_cutscene_npc_marker = Node2D.new()
		add_child(_cutscene_npc_marker)

	# Konversi koordinat layar (640x360) ke koordinat dunia kamera aktif agar bubble dialog muncul pas di titik tersebut
	var canvas_to_world: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	_cutscene_mc_marker.global_position = canvas_to_world * cutscene_mc_screen_pos
	_cutscene_npc_marker.global_position = canvas_to_world * cutscene_npc_screen_pos

	# 5. Fade layar kembali terang memperlihatkan gambar cutscene
	await _run_screen_fade(0.0, quiz_fade_duration)

	return {
		"mc": _cutscene_mc_marker,
		"npc": _cutscene_npc_marker
	}

func _exit_ending_cutscene() -> void:
	await _run_screen_fade(1.0, quiz_fade_duration)

	if _cutscene_layer and is_instance_valid(_cutscene_layer):
		_cutscene_layer.visible = false

	# Kembalikan kamera dari zoom NPC ke posisi normal Player
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam:
		cam.top_level = _orig_cam_top_level
		cam.zoom = _orig_cam_zoom
		cam.global_position = _orig_cam_pos

	await _run_screen_fade(0.0, quiz_fade_duration)
