extends Area2D

# Centang "Has Note" di Inspector HANYA pada 1 tumpukan yang berisi catatan
@export var has_note: bool = false
# ID unik opsional untuk tumpukan kosong agar tetap tersapu jika pemain balik ke scene ini
@export var pile_id: String = ""
# Atur jarak turun kotak dialog saat membaca catatan agar pas di dekat border bawah layar
@export var note_dialogue_offset_y: float = 130.0
# Atur lama waktu layar tetap hitam saat menyapu daun (dalam detik)
@export var sweep_black_hold_duration: float = 1.2

@onready var sprite_daun: Node2D = $SpriteDaun if has_node("SpriteDaun") else null
@onready var sprite_catatan: Node2D = $SpriteCatatan if has_node("SpriteCatatan") else null
@onready var interact_icon: Node2D = $InteractIcon if has_node("InteractIcon") else null
@onready var dialogue_pivot: Marker2D = $DialoguePivot if has_node("DialoguePivot") else null
@onready var sweep_sfx: AudioStreamPlayer = $SweepSFX if has_node("SweepSFX") else null
@onready var found_sfx: AudioStreamPlayer = $FoundSFX if has_node("FoundSFX") else null

# Referensi UI Gambar Catatan & SFX Kertas
@onready var illustration_ui: CanvasLayer = $IllustrationUI if has_node("IllustrationUI") else null
@onready var paper_rect: Control = $IllustrationUI/PaperRect if has_node("IllustrationUI/PaperRect") else null
@onready var paper_sfx: AudioStreamPlayer = $IllustrationUI/PaperSFX if has_node("IllustrationUI/PaperSFX") else null

@export_group("Rustle Leaf Effect")
@export var leaf_textures: Array[Texture2D] = [
	preload("res://assets/animation/daun_1.png"),
	preload("res://assets/animation/daun_2.png"),
	preload("res://assets/animation/daun_3.png")
]
@export var leaf_step_sfx: AudioStream # Drag file SFX injak daun ke sini lewat Inspector
@export var leaf_sfx_volume_db: float = -4.0
@export var rustle_cooldown: float = 0.65

var _rustle_timer: float = 0.0

var player_in_range: bool = false
var player_ref: Node2D = null
var hover_tween: Tween = null
var is_interacting: bool = false
var is_swept: bool = false
var paper_target_y: float = 0.0

func _ready() -> void:
	if interact_icon:
		interact_icon.visible = false
	if illustration_ui:
		illustration_ui.visible = false

	if paper_rect:
		paper_target_y = paper_rect.position.y

	if sprite_daun:
		sprite_daun.visible = true
	if sprite_catatan:
		sprite_catatan.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if has_note and GameState.get("vietnam_clue_leaves_found") == true:
		_set_swept_visual()
	elif not has_note and pile_id != "" and GameState.get("swept_empty_piles") is Dictionary and GameState.swept_empty_piles.has(pile_id):
		_set_swept_visual()

func _physics_process(delta: float) -> void:
	if _is_pile_cleared():
		return

	if _rustle_timer > 0.0:
		_rustle_timer -= delta

	if player_in_range and is_instance_valid(player_ref) and _rustle_timer <= 0.0:
		var is_moving: bool = false
		if "velocity" in player_ref and absf(player_ref.velocity.x) > 10.0:
			is_moving = true

		if is_moving:
			_rustle_timer = rustle_cooldown
			_spawn_flying_leaves(randi_range(2, 4))

func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name.to_lower().contains("player")

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = true
		player_ref = body
		if interact_icon and not is_interacting and _can_interact():
			interact_icon.visible = true
			_start_hover_tween()

func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = false
		if interact_icon:
			interact_icon.visible = false
			_stop_hover_tween()

func _can_interact() -> bool:
	# Tidak bisa di-interact sebelum berbicara dengan NPC petani (quest dimulai)
	if not GameState or GameState.get("vietnam_quest_started") != true:
		return false
	if is_swept and not has_note:
		return false
	return true

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
	if is_interacting or not _can_interact():
		return

	if player_in_range and event.is_action_pressed("interact"):
		if DialogueManager and "is_active" in DialogueManager and DialogueManager.is_active:
			return
		_handle_interaction()

func _get_pivot() -> Node2D:
	if is_instance_valid(dialogue_pivot):
		return dialogue_pivot
	if is_instance_valid(player_ref) and player_ref.has_node("DialoguePivot"):
		return player_ref.get_node("DialoguePivot")
	return self

func _set_swept_visual() -> void:
	is_swept = true
	if sprite_daun:
		sprite_daun.visible = false
	if sprite_catatan:
		sprite_catatan.visible = has_note

func _check_has_fork() -> bool:
	if not GameState:
		return false
	return GameState.get("vietnam_has_garden_fork") == true

func _handle_interaction() -> void:
	if not DialogueManager:
		return

	is_interacting = true
	if interact_icon:
		interact_icon.visible = false
		_stop_hover_tween()

	if is_instance_valid(player_ref) and "can_move" in player_ref:
		player_ref.can_move = false

	var pivot: Node2D = _get_pivot()

	# 1. Jika sudah disapu & punya catatan -> baca ulang catatan
	if is_swept and has_note:
		await _show_note_with_illustration(pivot)
		_finish_interaction()
		return

	# 2. Belum disapu -> cek apakah player sudah punya garpu taman
	if not _check_has_fork():
		await _say([
			"Tumpukan daun kering ini cukup tebal.",
			"Sepertinya aku butuh garpu taman atau alat untuk menyapunya."
		], pivot)
		_finish_interaction()
		return

	# 3. Dialog awal sebelum layar menghitam untuk menyapu
	await _say([
		"Mari kita bersihkan tumpukan daun kering ini pakai garpu taman..."
	], pivot)

	# 4. Transisi Fade Hitam + SFX Nyapu + Hilangkan Sprite Daun
	await _play_sweep_fade_sequence()

	# 5. Hasil setelah disapu & layar kembali terang
	if has_note:
		if found_sfx:
			found_sfx.play()

		await _say([
			"Eh, ada secarik catatan tersembunyi di bawah tumpukan daun tadi!"
		], pivot)

		await _show_note_with_illustration(pivot)

		if not GameState.vietnam_clue_leaves_found:
			GameState.vietnam_clue_leaves_found = true
			if QuestManager and QuestManager.has_method("add_progress"):
				QuestManager.add_progress("quest_kopi_1", 1)
	else:
		if pile_id != "" and GameState.get("swept_empty_piles") is Dictionary:
			GameState.swept_empty_piles[pile_id] = true

		await _say([
			"Kosong, tidak ada apa-apa di bawahnya."
		], pivot)

	_finish_interaction()

# --- TRANSISI LAYAR HITAM & SFX MENYAPU ---
func _play_sweep_fade_sequence() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 15
	var black_rect := ColorRect.new()
	black_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(black_rect)
	add_child(fade_layer)

	var fade_in := create_tween()
	fade_in.tween_property(black_rect, "color:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished

	if sweep_sfx:
		sweep_sfx.play()
	_set_swept_visual()

	await get_tree().create_timer(sweep_black_hold_duration).timeout

	var fade_out := create_tween()
	fade_out.tween_property(black_rect, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished

	fade_layer.queue_free()

# --- ANIMASI SLIDE HALUS (TANPA MANTUL) + SFX + DIALOG DEKAT BORDER BAWAH ---
func _show_note_with_illustration(pivot: Node2D) -> void:
	var screen_height: float = get_viewport().get_visible_rect().size.y

	if illustration_ui:
		illustration_ui.visible = true

	if paper_sfx:
		paper_sfx.play()

	if paper_rect:
		paper_rect.position.y = screen_height + 20.0
		var tween_in: Tween = create_tween()
		tween_in.tween_property(paper_rect, "position:y", paper_target_y, 0.4)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)
		await tween_in.finished

	var original_pivot_pos: Vector2 = pivot.position
	pivot.position = original_pivot_pos + Vector2(0, note_dialogue_offset_y)

	await _say([
		"[Catatan Kebun]: Daun kering yang disebar di sekitar tanaman berfungsi sebagai mulsa alami.",
		"Lapisan ini membantu menjaga kelembaban tanah agar akar kopi tidak cepat kering."
	], pivot)

	pivot.position = original_pivot_pos

	if paper_sfx:
		paper_sfx.play()

	if paper_rect:
		var tween_out: Tween = create_tween()
		tween_out.tween_property(paper_rect, "position:y", screen_height + 20.0, 0.35)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
		await tween_out.finished

	if illustration_ui:
		illustration_ui.visible = false

func _finish_interaction() -> void:
	if is_instance_valid(player_ref) and "can_move" in player_ref:
		player_ref.can_move = true

	is_interacting = false
	if player_in_range and interact_icon and _can_interact():
		interact_icon.visible = true
		_start_hover_tween()

func _say(lines: Array[String], pivot: Node2D) -> void:
	DialogueManager.start_dialogue(lines, pivot)
	if "is_active" in DialogueManager:
		while DialogueManager.is_active:
			await get_tree().process_frame
	elif DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	elif DialogueManager.has_signal("dialogue_ended"):
		await DialogueManager.dialogue_ended

func _spawn_flying_leaves(count: int = 3) -> void:
	if _is_pile_cleared():
		return

	_play_leaf_step_sfx()

	if leaf_textures.is_empty():
		return
	# ... lanjutkan kode spawn sprite daun terbang seperti sebelumnya ...

	var move_dir: float = 0.0
	if is_instance_valid(player_ref) and "velocity" in player_ref:
		move_dir = signf(player_ref.velocity.x)

	for i in range(count):
		var chosen_tex: Texture2D = leaf_textures.pick_random()
		if not chosen_tex:
			continue

		var leaf := Sprite2D.new()
		leaf.texture = chosen_tex
		leaf.z_index = 12
		leaf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		var base_origin_x: float = player_ref.global_position.x if is_instance_valid(player_ref) else global_position.x
		# Batasi agar tetap di dalam lebar tumpukan daun (-45 s.d. +45 dari pusat tumpukan)
		base_origin_x = clampf(base_origin_x, global_position.x - 45.0, global_position.x + 45.0)

		var side: float = -1.0 if randf() > 0.5 else 1.0
		var offset_x: float = side * randf_range(8.0, 26.0)
		var offset_y: float = randf_range(-8.0, 4.0)
		leaf.global_position = Vector2(base_origin_x + offset_x, global_position.y + offset_y)

		var random_scale := randf_range(0.75, 1.05)
		leaf.scale = Vector2(random_scale, random_scale)
		leaf.flip_h = randf() > 0.5
		leaf.rotation = randf_range(-0.4, 0.4)

		get_tree().current_scene.add_child(leaf)

		# 50% peluang menjadi daun yang jatuh melayang-layang perlahan
		var is_floating_leaf: bool = randf() > 0.5

		if is_floating_leaf:
			# --- POLA 1: TERANGKAT LALU JATUH MELAYANG BERAYUN ---
			var total_duration := randf_range(1.6, 2.2)
			var rise_time := total_duration * 0.3
			var fall_time := total_duration * 0.7

			var peak_y := leaf.global_position.y - randf_range(38.0, 58.0)
			var ground_y := leaf.global_position.y + randf_range(2.0, 8.0)
			var base_x := leaf.global_position.x + (move_dir * randf_range(12.0, 28.0))
			var sway_amount := randf_range(14.0, 24.0) * (-1.0 if randf() > 0.5 else 1.0)

			# Tween vertikal: naik perlahan, lalu turun pelan-pelan
			var tween_y := create_tween()
			tween_y.tween_property(leaf, "global_position:y", peak_y, rise_time)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween_y.tween_property(leaf, "global_position:y", ground_y, fall_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			# Tween horizontal & rotasi: berayun kanan-kiri seperti daun melayang
			var tween_sway := create_tween()
			tween_sway.tween_property(leaf, "global_position:x", base_x + sway_amount, total_duration * 0.35)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween_sway.tween_property(leaf, "global_position:x", base_x - sway_amount, total_duration * 0.35)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween_sway.tween_property(leaf, "global_position:x", base_x + (sway_amount * 0.4), total_duration * 0.30)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			var tween_rot := create_tween()
			tween_rot.tween_property(leaf, "rotation", 0.55, total_duration * 0.35).set_trans(Tween.TRANS_SINE)
			tween_rot.tween_property(leaf, "rotation", -0.55, total_duration * 0.35).set_trans(Tween.TRANS_SINE)
			tween_rot.tween_property(leaf, "rotation", 0.15, total_duration * 0.30).set_trans(Tween.TRANS_SINE)

			# Memudar halus di akhir sebelum menyentuh tanah
			var tween_fade := create_tween()
			tween_fade.tween_property(leaf, "modulate:a", 0.0, total_duration * 0.35)\
				.set_delay(total_duration * 0.65)
			tween_fade.tween_callback(leaf.queue_free)
		else:
			# --- POLA 2: TERHEMPAS PENDEK ---
			var short_duration := randf_range(0.75, 1.05)
			var drift_x := randf_range(-22.0, 22.0) + (move_dir * randf_range(12.0, 26.0))
			var peak_y := leaf.global_position.y - randf_range(18.0, 30.0)
			var end_y := leaf.global_position.y + randf_range(0.0, 6.0)

			var tween := create_tween().set_parallel(true)
			tween.tween_property(leaf, "global_position:y", peak_y, short_duration * 0.45)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(leaf, "global_position:y", end_y, short_duration * 0.55)\
				.set_delay(short_duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.tween_property(leaf, "global_position:x", leaf.global_position.x + drift_x, short_duration)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(leaf, "rotation", leaf.rotation + randf_range(-2.2, 2.2), short_duration)
			tween.tween_property(leaf, "modulate:a", 0.0, short_duration * 0.4)\
				.set_delay(short_duration * 0.6)
			tween.chain().tween_callback(leaf.queue_free)

func _is_pile_cleared() -> bool:
	# Sesuaikan dengan nama variabel status di tumpukan_daun_kering.gd milikmu
	if ("is_cleaned" in self and self.is_cleaned) \
	or ("is_swept" in self and self.is_swept) \
	or ("is_cleared" in self and self.is_cleared) \
	or ("sudah_disapu" in self and self.sudah_disapu):
		return true

	# Jika sprite tumpukan daun sudah disembunyikan setelah disapu
	var pile_sprite := get_node_or_null("Sprite2D")
	if pile_sprite and not pile_sprite.visible:
		return true

	return false

func _play_leaf_step_sfx() -> void:
	if not leaf_step_sfx:
		return

	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = leaf_step_sfx
	sfx_player.volume_db = leaf_sfx_volume_db
	# Sedikit variasi pitch supaya bunyi gemerisik daun tidak terdengar sama persis tiap langkah
	sfx_player.pitch_scale = randf_range(0.9, 1.12)
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)
