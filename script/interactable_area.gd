extends Area2D

signal interacted

@onready var interact_icon: Sprite2D = $InteractIcon

var player_in_area: bool = false
var is_active: bool = true
var tween: Tween
var default_y: float

func _ready() -> void:
	# Simpan posisi awal Y milik icon
	default_y = interact_icon.position.y
	interact_icon.hide()
	
	# Connect signal bawaan Area2D
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_active and player_in_area and event.is_action_pressed("interact"):
		complete_interaction()

func _on_body_entered(body: Node2D) -> void:
	if is_active and body is CharacterBody2D:
		player_in_area = true
		start_hover()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_in_area = false
		stop_hover()

func start_hover() -> void:
	# Matikan tween lama jika sedang berjalan
	if tween and tween.is_running():
		tween.kill()
		
	# Reset posisi Y ke titik semula dan tampilkan icon
	interact_icon.position.y = default_y
	interact_icon.show()
	
	# Jalankan animasi melayang (hovering)
	tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(interact_icon, "position:y", default_y - 6.0, 0.5)
	tween.tween_property(interact_icon, "position:y", default_y + 2.0, 0.5)

func stop_hover() -> void:
	if tween and tween.is_running():
		tween.kill()
	interact_icon.position.y = default_y
	interact_icon.hide()

func complete_interaction() -> void:
	is_active = false
	stop_hover()
	$CollisionShape2D.set_deferred("disabled", true)
	emit_signal("interacted")
