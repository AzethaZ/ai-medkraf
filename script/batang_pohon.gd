extends Area2D

# Signal untuk memberitahu world_sembunyi jika pemain menekan tombol E di dekat pohon
signal tree_interacted

@onready var interact_icon: Sprite2D = $InteractIcon

var is_player_inside: bool = false
var tween: Tween = null
var base_icon_y: float = 0.0

func _ready() -> void:
	if interact_icon:
		base_icon_y = interact_icon.position.y
		interact_icon.visible = false

	# Hubungkan signal bawaan Area2D ke fungsi internalnya sendiri
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if interact_icon:
			interact_icon.visible = false
			stop_hover_animation()
		
		# Pancarkan signal ke scene world
		tree_interacted.emit()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_inside = true
		if interact_icon:
			interact_icon.visible = true
			start_hover_animation()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("player") or body.name.begins_with("Player"):
		is_player_inside = false
		if interact_icon:
			interact_icon.visible = false
			stop_hover_animation()

func start_hover_animation() -> void:
	if not interact_icon:
		return

	if tween and tween.is_running():
		tween.kill()

	interact_icon.position.y = base_icon_y
	tween = create_tween().set_loops()

	tween.tween_property(interact_icon, "position:y", base_icon_y - 4.0, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(interact_icon, "position:y", base_icon_y, 0.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func stop_hover_animation() -> void:
	if tween and tween.is_running():
		tween.kill()
