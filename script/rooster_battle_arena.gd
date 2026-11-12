extends Control

@onready var character_body: CharacterBody2D = $CharacterBody2D if has_node("CharacterBody2D") else null
@onready var rooster: Node2D = $Rooster if has_node("Rooster") else null
@onready var qte_minigame: Control = $RoosterQTEMinigame if has_node("RoosterQTEMinigame") else null
@onready var intro_label: Label = $IntroLabel if has_node("IntroLabel") else null
@onready var dim_overlay: ColorRect = $DimOverlay if has_node("DimOverlay") else null

# Referensi kontainer nyawa hati di arena
@onready var player_hearts: Node = $PlayerHearts if has_node("PlayerHearts") else null
@onready var rooster_hearts: Node = $RoosterHearts if has_node("RoosterHearts") else null

var player_current_health: int = 3
var rooster_current_health: int = 4

func _ready() -> void:
	if qte_minigame:
		qte_minigame.visible = false
		qte_minigame.connect("minigame_completed", _on_minigame_completed)
		qte_minigame.connect("player_damaged", _on_player_damaged)
		qte_minigame.connect("rooster_damaged", _on_rooster_damaged)

	if intro_label:
		intro_label.visible = false

	if dim_overlay:
		dim_overlay.modulate.a = 0.0 # Pastikan awal transparan

	# Sembunyikan hati nyawa di awal (selama intro READY-SET-FIGHT)
	if player_hearts:
		player_hearts.visible = false
	if rooster_hearts:
		rooster_hearts.visible = false

	# 1. Buka layar dari efek fade hitam (fade in) saat arena dimuat
	if SceneTransition and SceneTransition.has_method("fade_in"):
		await SceneTransition.fade_in()

	# 2. Atur posisi dan arah hadap Danum ke kiri (menghadap ayam)
	if character_body:
		if character_body.has_method("set_dialogue_state"):
			character_body.set_dialogue_state(true)
		else:
			if "is_in_battle" in character_body:
				character_body.is_in_battle = true
			character_body.set_physics_process(false)

		var sprite = character_body.find_child("AnimatedSprite2D", true, false)
		if sprite:
			sprite.flip_h = true

	# 3. Atur arah hadap Ayam Jago ke kanan (menghadap Danum)
	if rooster:
		var r_sprite = rooster.find_child("AnimatedSprite2D", true, false)
		if r_sprite:
			r_sprite.flip_h = false

	# 4. Jalankan animasi teks Intro & Gelap Layar
	await play_intro_sequence()

	# 5. Munculkan hati nyawa tepat setelah intro selesai
	if player_hearts:
		player_hearts.visible = true
	if rooster_hearts:
		rooster_hearts.visible = true

	# 6. Mulai Minigame QTE setelah intro selesai
	if qte_minigame and qte_minigame.has_method("start_minigame"):
		qte_minigame.start_minigame(character_body)


# --- ANIMASI INTRO TEXT & LAYAR MEREDUP ---
func play_intro_sequence() -> void:
	if not intro_label:
		return

	intro_label.visible = false
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Nyalakan efek gelap perlahan (semi-transparan hitam)
	if dim_overlay:
		var dim_tween = create_tween()
		dim_tween.tween_property(dim_overlay, "modulate:a", 0.5, 0.5)

	intro_label.visible = true
	var steps = ["READY", "SET", "FIGHT!"]

	for text in steps:
		intro_label.text = text
		intro_label.modulate.a = 0.0
		intro_label.scale = Vector2(0.2, 0.2)

		await get_tree().process_frame
		intro_label.pivot_offset = intro_label.size / 2.0

		var tween = create_tween().set_parallel(true)
		tween.tween_property(intro_label, "scale", Vector2(1.2, 1.2), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(intro_label, "modulate:a", 1.0, 0.4)
		await tween.finished
		
		await get_tree().create_timer(0.4).timeout

	await get_tree().create_timer(0.5).timeout

	var fade_tween = create_tween()
	fade_tween.tween_property(intro_label, "modulate:a", 0.0, 0.3)
	await fade_tween.finished

	intro_label.visible = false

	# Hilangkan efek gelap (kembali normal seperti biasa) saat pertarungan dimulai
	if dim_overlay:
		var undim_tween = create_tween()
		undim_tween.tween_property(dim_overlay, "modulate:a", 0.0, 0.4)
		await undim_tween.finished


# --- SISTEM NYAWA HATI (MC & AYAM) ---
func _on_player_damaged() -> void:
	player_current_health -= 1
	if player_hearts:
		var children = player_hearts.get_children()
		var index = children.size() - player_current_health - 1
		if index >= 0 and index < children.size():
			children[index].modulate.a = 0.2  # Hati MC meredup satu per satu

func _on_rooster_damaged() -> void:
	rooster_current_health -= 1
	if rooster_hearts:
		var children = rooster_hearts.get_children()
		var index = children.size() - rooster_current_health - 1
		if index >= 0 and index < children.size():
			children[index].modulate.a = 0.2  # Hati ayam meredup satu per satu


# --- KETIKA MINIGAME SELESAI ---
func _on_minigame_completed(success: bool) -> void:
	if success:
		print("QTE Berhasil! Ayam Jago berhasil dikalahkan.")
		if QuestManager:
			QuestManager.complete_quest("quest_ayam_3")

		if character_body and "is_in_battle" in character_body:
			character_body.is_in_battle = false

		if SceneTransition and SceneTransition.has_method("fade_out"):
			await SceneTransition.fade_out()

		get_tree().change_scene_to_file("res://scene/World/world_1.tscn")
		
	else:
		print("QTE Gagal! Kembali ke World 1.")

		if character_body and "is_in_battle" in character_body:
			character_body.is_in_battle = false

		# Efek Game Over menggunakan overlay dan label intro
		if dim_overlay:
			var game_over_dim = create_tween()
			game_over_dim.tween_property(dim_overlay, "modulate:a", 0.8, 0.4)

		if intro_label:
			intro_label.text = "GAME OVER"
			intro_label.modulate.a = 0.0
			intro_label.scale = Vector2(0.5, 0.5)
			intro_label.visible = true
			
			await get_tree().process_frame
			intro_label.pivot_offset = intro_label.size / 2.0

			var go_tween = create_tween().set_parallel(true)
			go_tween.tween_property(intro_label, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			go_tween.tween_property(intro_label, "modulate:a", 1.0, 0.3)
			await go_tween.finished

		# Jeda sebentar agar teks Game Over terbaca sebelum melakukan fade keluar scene
		await get_tree().create_timer(1.5).timeout

		if SceneTransition and SceneTransition.has_method("fade_out"):
			await SceneTransition.fade_out()

		get_tree().change_scene_to_file("res://scene/World/world_1.tscn")
