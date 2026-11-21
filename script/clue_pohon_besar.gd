extends Area2D

# Atur jarak turun kotak dialog saat membaca catatan agar pas di dekat border bawah layar
@export var note_dialogue_offset_y: float = 130.0

@onready var interact_icon: Node2D = $InteractIcon if has_node("InteractIcon") else null
@onready var found_sfx: AudioStreamPlayer = $FoundSFX if has_node("FoundSFX") else null
@onready var dialogue_pivot: Marker2D = $DialoguePivot if has_node("DialoguePivot") else null

# Referensi UI Gambar Catatan & SFX Kertas
@onready var illustration_ui: CanvasLayer = $IllustrationUI if has_node("IllustrationUI") else null
@onready var paper_rect: Control = $IllustrationUI/PaperRect if has_node("IllustrationUI/PaperRect") else null
@onready var paper_sfx: AudioStreamPlayer = $IllustrationUI/PaperSFX if has_node("IllustrationUI/PaperSFX") else null

var player_in_range: bool = false
var player_ref: Node2D = null
var hover_tween: Tween = null
var is_interacting: bool = false
var paper_target_y: float = 0.0

func _ready() -> void:
	if interact_icon:
		interact_icon.visible = false
	if illustration_ui:
		illustration_ui.visible = false

	# Simpan posisi Y asli PaperRect yang sudah diatur di tengah layar
	if paper_rect:
		paper_target_y = paper_rect.position.y

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name.to_lower().contains("player")

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body) and GameState.get("vietnam_quest_started") == true:
		player_in_range = true
		player_ref = body
		if interact_icon and not is_interacting:
			interact_icon.visible = true
			_start_hover_tween()

func _on_body_exited(body: Node2D) -> void:
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
	if is_interacting:
		return

	if player_in_range and event.is_action_pressed("interact"):
		if DialogueManager and "is_active" in DialogueManager and DialogueManager.is_active:
			return
		_handle_interaction()

func _get_pivot() -> Node2D:
	if is_instance_valid(dialogue_pivot):
		return dialogue_pivot
	if is_instance_valid(player_ref):
		if player_ref.has_node("DialoguePivot"):
			return player_ref.get_node("DialoguePivot")
		var temp_pivot := Marker2D.new()
		temp_pivot.name = "DialoguePivot"
		temp_pivot.position = Vector2(0, -60)
		player_ref.add_child(temp_pivot)
		return temp_pivot
	return self

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
	var is_first_time: bool = not GameState.get("vietnam_clue_tree_found")

	# Dialog awal saat menemukan catatan di dekat pohon besar
	if is_first_time:
		if found_sfx:
			found_sfx.play()
		await _say([
			"Pohon-pohon di sekitar kebun ini besar dan rindang sekali.",
			"Eh, ada catatan yang terselip di dekat batang pohon ini!"
		], pivot)

	# Tampilkan gambar kertas catatan (slide naik + SFX kertas + dialog dekat border bawah)
	await _show_note_with_illustration(pivot)

	# Update progres quest jika baru pertama kali ditemukan
	if is_first_time:
		GameState.vietnam_clue_tree_found = true
		if QuestManager and QuestManager.has_method("add_progress"):
			QuestManager.add_progress("quest_kopi_1", 1)

	if is_instance_valid(player_ref) and "can_move" in player_ref:
		player_ref.can_move = true

	is_interacting = false
	if player_in_range and interact_icon:
		interact_icon.visible = true
		_start_hover_tween()

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
		"[Catatan Kebun]: Pohon-pohon besar ditanam di antara tanaman kopi sebagai naungan alami.",
		"Kanopinya melindungi tanaman kopi dari terik matahari langsung agar kualitas bijinya tetap terjaga."
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

func _say(lines: Array[String], pivot: Node2D) -> void:
	DialogueManager.start_dialogue(lines, pivot)
	if "is_active" in DialogueManager:
		while DialogueManager.is_active:
			await get_tree().process_frame
	elif DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	elif DialogueManager.has_signal("dialogue_ended"):
		await DialogueManager.dialogue_ended
