extends CharacterBody2D

@onready var interact_icon: Sprite2D = $InteractIcon
@onready var dialogue_pivot: Node2D = $DialoguePivot
@onready var chat_detection: Area2D = $chat_detection
@onready var npc_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player_in_range: bool = false
var player_ref: Node2D = null
var has_talked: bool = false

var _icon_base_y: float = 0.0
var _icon_hover_tween: Tween = null

var first_dialogues: Array[Dictionary] = [
	{"speaker": "npc", "text": "Tahu tidak? Hutan sini asalnya tempat ayam hutan liar Tiongkok dijinakkan ribuan tahun lalu!"},
	{"speaker": "danum", "text": "Pantas saja ayam-ayam di sini terlihat betah berkeliaran bebas."},
	{"speaker": "npc", "text": "Iya! Mereka sudah terbiasa cari makan di balik rimbun bambu sejak dulu."}
]

var repeat_dialogues: Array[Dictionary] = [
	{"speaker": "npc", "text": "Ayam-ayam di hutan sini masih jago terbang pendek ke dahan pohon kalau sore tiba!"}
]

func _ready() -> void:
	if interact_icon:
		_icon_base_y = interact_icon.position.y
		interact_icon.visible = false
	if chat_detection:
		chat_detection.body_entered.connect(_on_body_entered)
		chat_detection.body_exited.connect(_on_body_exited)

func _set_interact_icon_visible(show_icon: bool) -> void:
	if not is_instance_valid(interact_icon):
		return

	if _icon_hover_tween and _icon_hover_tween.is_valid():
		_icon_hover_tween.kill()
		_icon_hover_tween = null

	interact_icon.visible = show_icon
	interact_icon.position.y = _icon_base_y

	if show_icon:
		_icon_hover_tween = create_tween().set_loops()
		_icon_hover_tween.tween_property(interact_icon, "position:y", _icon_base_y - 4.0, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_icon_hover_tween.tween_property(interact_icon, "position:y", _icon_base_y, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "Player" or body is CharacterBody2D:
		player_in_range = true
		player_ref = body as Node2D
		_set_interact_icon_visible(true)

func _on_body_exited(body: Node) -> void:
	if body == player_ref:
		player_in_range = false
		player_ref = null
		_set_interact_icon_visible(false)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		if DialogueManager and not DialogueManager.is_active:
			_start_chat()

func _get_player_dialogue_pivot() -> Node2D:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player_ref) and get_tree().current_scene:
		player_ref = get_tree().current_scene.find_child("Player", true, false) as Node2D

	if is_instance_valid(player_ref):
		return player_ref.get_node_or_null("DialoguePivot") as Node2D

	return null

func _start_chat() -> void:
	_set_interact_icon_visible(false)

	# Hadapkan NPC ke arah Danum
	if is_instance_valid(player_ref) and npc_sprite:
		npc_sprite.flip_h = player_ref.global_position.x < global_position.x

	var lines := repeat_dialogues if has_talked else first_dialogues
	has_talked = true

	var mc_pivot: Node2D = _get_player_dialogue_pivot()

	for entry in lines:
		var target_pivot: Node2D = dialogue_pivot
		if entry["speaker"] == "danum" and is_instance_valid(mc_pivot):
			target_pivot = mc_pivot

		var line_arr: Array[String] = [entry["text"]]
		DialogueManager.start_dialogue(line_arr, target_pivot)

		while DialogueManager.is_active:
			await get_tree().process_frame

	if player_in_range:
		_set_interact_icon_visible(true)
