extends CharacterBody2D

@export var block_size: float = 16.0
@export var max_blocks: float = 3.0
@export var speed: float = 30.0

var start_x: float = 0.0
var move_direction: int = 1
var is_player_in_chat_zone: bool = false
var is_chatting: bool = false

# Node UI
@onready var chat_detection: Area2D = $chat_detection
@onready var interact_label: Label = $Label
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var dialogue_ui: Control = $DialogueUI
@onready var dialogue_label: Label = $DialogueUI/NinePatchRect/VBoxContainer/Label
@onready var choices_container: VBoxContainer = $DialogueUI/NinePatchRect/VBoxContainer/VBoxContainer

# Data Percakapan & Pilihan
var dialogue_data = {
	"text": "Hai",
	"choices": [
		{"text": "assalamualaikum", "next": "kegiatan"},
		{"text": "fuck you", "next": "close"}
	]
}

var responses = {
	"kegiatan": "waalaikumsalam",
	"close": "p maksud"
}

func _ready() -> void:
	start_x = global_position.x
	if interact_label: interact_label.visible = false
	if dialogue_ui: dialogue_ui.visible = false
	
	chat_detection.body_entered.connect(_on_chat_detection_body_entered)
	chat_detection.body_exited.connect(_on_chat_detection_body_exited)

func _physics_process(_delta: float) -> void:
	# Berhenti jalan jika diajak bicara
	if is_chatting:
		velocity.x = 0
		if sprite and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		return

	# Logika Patroli
	var travel_distance = max_blocks * block_size
	if global_position.x >= start_x + travel_distance:
		move_direction = -1
		if sprite: sprite.flip_h = false
	elif global_position.x <= start_x - travel_distance:
		move_direction = 1
		if sprite: sprite.flip_h = true

	velocity.x = move_direction * speed
	move_and_slide()
	if sprite and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")

func _unhandled_input(event: InputEvent) -> void:
	if is_player_in_chat_zone and not is_chatting and event.is_action_pressed("interact"):
		start_dialogue()

func start_dialogue() -> void:
	is_chatting = true
	if interact_label: interact_label.visible = false
	dialogue_ui.visible = true
	
	# Tampilkan teks utama NPC
	dialogue_label.text = dialogue_data["text"]
	
	# Bersihkan tombol pilihan lama jika ada
	for child in choices_container.get_children():
		child.queue_free()
		
	# Buat tombol pilihan secara dinamis
	for choice in dialogue_data["choices"]:
		var btn = Button.new()
		btn.text = choice["text"]
		btn.pressed.connect(_on_choice_selected.bind(choice["next"]))
		choices_container.add_child(btn)

func _on_choice_selected(next_key: String) -> void:
	# Bersihkan tombol pilihan setelah dipilih
	for child in choices_container.get_children():
		child.queue_free()

	if next_key == "close":
		dialogue_label.text = responses["close"]
		await get_tree().create_timer(1.2).timeout
		end_dialogue()
	else:
		# Tampilkan respon dari pilihan
		dialogue_label.text = responses[next_key]
		
		# Tambahkan tombol untuk menutup/kembali
		var back_btn = Button.new()
		back_btn.text = "[Tutup]"
		back_btn.pressed.connect(end_dialogue)
		choices_container.add_child(back_btn)

func end_dialogue() -> void:
	is_chatting = false
	dialogue_ui.visible = false
	if is_player_in_chat_zone and interact_label:
		interact_label.visible = true

func _on_chat_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_in_chat_zone = true
		if interact_label and not is_chatting:
			interact_label.visible = true

func _on_chat_detection_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_in_chat_zone = false
		if interact_label:
			interact_label.visible = false
		end_dialogue() # Otomatis tutup dialog jika player jalan menjauh
