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
