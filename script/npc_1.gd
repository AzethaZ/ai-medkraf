extends CharacterBody2D

# --- REFERENSI NODE ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var chat_detection: Area2D = $chat_detection
@onready var interact_icon: Sprite2D = $InteractIcon

# Node UI Dialog
@onready var dialogue_ui: Control = $DialogueUI
@onready var dialogue_box: PanelContainer = $DialogueUI/PanelContainer
@onready var dialogue_label: Label = $DialogueUI/PanelContainer/VBoxContainer/Label

# --- VARIABEL PATROLI / PERGERAKAN ---
@export var speed: float = 30.0
@export var move_distance: float = 60.0 # Jarak patroli
var start_x: float = 0.0
var direction: int = 1 # 1 = Kanan, -1 = Kiri

# --- DATA DIALOG NPC 1 ---
var dialogue_lines: Array[String] = [
	"Hai! Selamat datang di area ini.",
	"Aku punya beberapa informasi penting untukmu.",
	"Pastikan kamu berhati-hati saat menjelajahi area hutan di depan.",
	"Semoga perjalananmu lancar!"
]

# --- VARIABEL STATE ---
var is_player_in_chat_zone: bool = false
var is_chatting: bool = false
var current_line_index: int = 0
var tween: Tween
var text_tween: Tween

func _ready() -> void:
	start_x = global_position.x
	
	if interact_icon:
		interact_icon.visible = false
		
	if dialogue_ui:
		dialogue_ui.visible = false
	
	chat_detection.body_entered.connect(_on_chat_detection_body_entered)
	chat_detection.body_exited.connect(_on_chat_detection_body_exited)

func _physics_process(_delta: float) -> void:
	# Jika sedang mengobrol dengan pemain, NPC berhenti bergerak
	if is_chatting:
		velocity.x = 0
		if sprite and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		move_and_slide()
		return

	# Logika Pergerakan Patroli
	velocity.x = direction * speed
	
	# Balik arah jika sudah mencapai batas patroli
	if global_position.x >= start_x + move_distance:
		direction = -1
	elif global_position.x <= start_x - move_distance:
		direction = 1
		
	# Flip sprite sesuai arah jalan
	if sprite:
		sprite.flip_h = (direction < 0)
		if sprite.sprite_frames.has_animation("walk"):
			sprite.play("walk")

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if is_player_in_chat_zone and event.is_action_pressed("interact"):
		if not is_chatting:
			start_dialogue()
		else:
			# Skip animasi ketik jika masih berjalan, atau lanjut kalimat jika sudah selesai
			if text_tween and text_tween.is_running():
				text_tween.kill()
				dialogue_label.visible_ratio = 1.0
			else:
				advance_dialogue()

# --- LOGIKA DIALOG ---
func start_dialogue() -> void:
	is_chatting = true
	current_line_index = 0
	
	if interact_icon:
		interact_icon.visible = false
		stop_hover_animation()
		
	dialogue_ui.visible = true
	show_current_line()

func show_current_line() -> void:
	if text_tween and text_tween.is_running():
		text_tween.kill()

	# Set teks
	dialogue_label.text = dialogue_lines[current_line_index]
	
	# Reset ukuran & pertahankan posisi titik tengah di atas NPC
	dialogue_box.reset_size()
	dialogue_box.position.x = -dialogue_box.size.x / 2.0
	
	# Animasi typewriter dari kiri
	dialogue_label.visible_ratio = 0.0
	var text_length = dialogue_lines[current_line_index].length()
	var duration = text_length * 0.03
	
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
	
	if is_player_in_chat_zone and interact_icon:
		interact_icon.visible = true
		start_hover_animation()

# --- DETEKSI PLAYER ---
func _on_chat_detection_body_entered(body: Node2D) -> void:
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
		end_dialogue()

# --- EFEK HOVER IKON E ---
func start_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_loops()
	tween.tween_property(interact_icon, "position:y", -4.0, 0.6)\
		.as_relative()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(interact_icon, "position:y", 4.0, 0.6)\
		.as_relative()\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func stop_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
