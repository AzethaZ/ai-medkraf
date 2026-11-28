extends Area2D

# Atur lama waktu layar tetap hitam saat mengambil barang (dalam detik)
@export var black_hold_duration: float = 1.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var interact_icon: Node2D = $InteractIcon if has_node("InteractIcon") else null
@onready var pickup_sfx: AudioStreamPlayer = $PickupSFX if has_node("PickupSFX") else null

var player_in_range: bool = false
var player_ref: Node2D = null
var hover_tween: Tween = null
var is_picked_up: bool = false

func _ready() -> void:
	if GameState.get("vietnam_has_garden_fork") == true:
		queue_free()
		return

	if interact_icon:
		interact_icon.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name.to_lower().contains("player")

func _on_body_entered(body: Node2D) -> void:
	if is_picked_up:
		return
	if _is_player(body) and GameState.get("vietnam_quest_started") == true:
		player_in_range = true
		player_ref = body
		if interact_icon:
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
	if is_picked_up:
		return
	if player_in_range and event.is_action_pressed("interact"):
		if DialogueManager and "is_active" in DialogueManager and DialogueManager.is_active:
			return
		_pickup_fork()

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
		return self

	if player.has_node("DialoguePivot"):
		return player.get_node("DialoguePivot")

	var temp_pivot := Marker2D.new()
	temp_pivot.name = "DialoguePivot"
	temp_pivot.position = Vector2(0, -45)
	player.add_child(temp_pivot)
	return temp_pivot

func _pickup_fork() -> void:
	is_picked_up = true
	GameState.vietnam_has_garden_fork = true

	if interact_icon:
		interact_icon.visible = false
		_stop_hover_tween()

	var player: Node2D = _get_player_node()
	var pivot: Node2D = _get_player_dialogue_pivot(player)

	if player and "can_move" in player:
		player.can_move = false

	# 1. Dialog awal MC sebelum layar menghitam
	if DialogueManager:
		await _say(["Ini pasti sapunya!"], pivot)

	# --- BUAT OVERLAY LAYAR HITAM UNTUK FADE IN & FADE OUT ---
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 15
	var black_rect := ColorRect.new()
	black_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(black_rect)
	add_child(fade_layer)

	# 2. Layar perlahan menghitam (Fade In ke Hitam)
	var fade_in := create_tween()
	fade_in.tween_property(black_rect, "color:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished

	# 3. Saat layar gelap penuh: putar SFX ambil & hilangkan gambar garpu dari tanah
	if pickup_sfx:
		pickup_sfx.play()
	if sprite:
		sprite.stop()
		sprite.visible = false

	# Tahan layar hitam lebih lama (bisa diatur di Inspector lewat Black Hold Duration)
	await get_tree().create_timer(black_hold_duration).timeout

	# 4. Layar kembali terang (Fade Out dari Hitam)
	var fade_out := create_tween()
	fade_out.tween_property(black_rect, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished

	fade_layer.queue_free()

	# 5. Dialog lanjutan MC setelah barang diambil
	if DialogueManager:
		await _say([
			"Aku mendapatkan Garpu Taman!",
			"Ini pasti berguna untuk membersihkan tumpukan daun kering."
		], pivot)

	if player and "can_move" in player:
		player.can_move = true

	queue_free()

func _say(lines: Array[String], pivot: Node2D) -> void:
	DialogueManager.start_dialogue(lines, pivot)
	if "is_active" in DialogueManager:
		while DialogueManager.is_active:
			await get_tree().process_frame
	elif DialogueManager.has_signal("dialogue_finished"):
		await DialogueManager.dialogue_finished
	elif DialogueManager.has_signal("dialogue_ended"):
		await DialogueManager.dialogue_ended
