@tool
extends Area2D

const CLEANING_MINIGAME_SCENE: PackedScene = preload("res://scene/Function/cleaning_minigame.tscn")

@export var spot_id: String = "room1_spot1"
@export var required_stage: int = 1
@export var spots_in_room: int = 2
@export var sweep_speed: float = 1.35
@export var hits_required: int = 3

@export var dirty_texture: Texture2D:
	set(value):
		dirty_texture = value
		_update_editor_preview()

@export var clean_texture: Texture2D:
	set(value):
		clean_texture = value
		_update_editor_preview()

@export var sprite_scale: Vector2 = Vector2.ONE:
	set(value):
		sprite_scale = value
		_update_editor_preview()

@export var interaction_radius: float = 40.0:
	set(value):
		interaction_radius = value
		_update_editor_preview()

@onready var dirty_sprite: Sprite2D = $DirtySprite
@onready var clean_sprite: Sprite2D = $CleanSprite
@onready var interact_icon: Sprite2D = $InteractIcon

var player_in_range: bool = false
var player_ref: Node2D = null
var is_cleaned: bool = false
var active_layer: CanvasLayer = null

var icon_base_scale: Vector2 = Vector2.ONE
var icon_base_y: float = 0.0
var icon_hover_tween: Tween = null


func _ready() -> void:
	if interact_icon:
		icon_base_scale = interact_icon.scale
		icon_base_y = interact_icon.position.y
		# Pastikan skala global tetap konsisten meski parent di-scale
		if global_scale != Vector2.ZERO:
			interact_icon.global_scale = icon_base_scale
	_update_editor_preview()
	if Engine.is_editor_hint():
		return

	# ... sisa kode _ready() milikmu (body_entered, GameState, dll.) tetap sama
	if dirty_sprite and dirty_texture:
		dirty_sprite.texture = dirty_texture
	if clean_sprite and clean_texture:
		clean_sprite.texture = clean_texture

	# ... biarkan sisa kode _ready() di bawahnya tetap seperti semula
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	interact_icon.visible = false

	if GameState.hotel_cleaned_objects.has(spot_id):
		_set_cleaned_visuals()


func _can_interact_now() -> bool:
	if required_stage == 1:
		return QuestManager != null and QuestManager.get_quest_status("quest_hotel_1") == "ACTIVE"
	elif required_stage == 2:
		if QuestManager == null:
			return false
		var q1_done: bool = QuestManager.get_quest_status("quest_hotel_1") == "COMPLETED"
		var q2_active: bool = QuestManager.get_quest_status("quest_hotel_2") == "ACTIVE"
		if q1_done and q2_active:
			GameState.hotel_quest_stage = 2
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if is_cleaned or active_layer != null:
		return

	if player_in_range and _can_interact_now():
		if event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_start_minigame()


func _start_minigame() -> void:
	interact_icon.visible = false

	if player_ref and player_ref.has_method("disable_movement"):
		player_ref.disable_movement()

	active_layer = CanvasLayer.new()
	active_layer.layer = 30
	add_child(active_layer)

	var minigame_ui = CLEANING_MINIGAME_SCENE.instantiate()
	minigame_ui.sweep_speed = sweep_speed
	minigame_ui.hits_required = hits_required
	active_layer.add_child(minigame_ui)
	minigame_ui.cleaning_completed.connect(_on_cleaning_completed)


func _on_cleaning_completed() -> void:
	active_layer = null

	if player_ref and player_ref.has_method("enable_movement"):
		player_ref.enable_movement()

	_set_cleaned_visuals()

	if not GameState.hotel_cleaned_objects.has(spot_id):
		GameState.hotel_cleaned_objects.append(spot_id)

	var prefix: String = "room1_" if required_stage == 1 else "room2_"
	var cleaned_in_room: int = 0
	for id in GameState.hotel_cleaned_objects:
		if str(id).begins_with(prefix):
			cleaned_in_room += 1

	var quest_id: String = "quest_hotel_1" if required_stage == 1 else "quest_hotel_2"
	if QuestManager and QuestManager.get_quest_status(quest_id) == "ACTIVE":
		QuestManager.add_quest_progress(quest_id, 1)

	if cleaned_in_room >= spots_in_room:
		GameState.hotel_quest_stage = required_stage + 1
	if cleaned_in_room >= spots_in_room:
		GameState.hotel_quest_stage = required_stage + 1
	elif QuestManager and QuestManager.get_quest_status(quest_id) != "ACTIVE":
		GameState.hotel_quest_stage = required_stage + 1


func _set_cleaned_visuals() -> void:
	is_cleaned = true
	interact_icon.visible = false
	dirty_sprite.visible = false
	clean_sprite.visible = true


func _on_body_entered(body: Node2D) -> void:
	interact_icon.visible = true
	_start_icon_hover()
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true
		player_ref = body
		if not is_cleaned and _can_interact_now():
			interact_icon.visible = true


func _on_body_exited(body: Node2D) -> void:
	_stop_icon_hover()
	interact_icon.visible = false
	if body == player_ref or body.is_in_group("player") or body.name == "Player":
		player_in_range = false
		player_ref = null
		interact_icon.visible = false

func _update_editor_preview() -> void:
	var d_sprite := get_node_or_null("DirtySprite") as Sprite2D
	var c_sprite := get_node_or_null("CleanSprite") as Sprite2D
	if d_sprite:
		if dirty_texture:
			d_sprite.texture = dirty_texture
		d_sprite.scale = sprite_scale
	if c_sprite:
		if clean_texture:
			c_sprite.texture = clean_texture
		c_sprite.scale = sprite_scale

	var col_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape and col_shape.shape is CircleShape2D:
		if not col_shape.shape.resource_local_to_scene:
			col_shape.shape = col_shape.shape.duplicate()
			col_shape.shape.resource_local_to_scene = true
		(col_shape.shape as CircleShape2D).radius = interaction_radius

func _start_icon_hover() -> void:
	if not interact_icon:
		return
	_stop_icon_hover()
	interact_icon.position.y = icon_base_y
	icon_hover_tween = create_tween().set_loops()
	icon_hover_tween.tween_property(interact_icon, "position:y", icon_base_y - 4.0, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	icon_hover_tween.tween_property(interact_icon, "position:y", icon_base_y, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_icon_hover() -> void:
	if icon_hover_tween and icon_hover_tween.is_valid():
		icon_hover_tween.kill()
	icon_hover_tween = null
	if interact_icon:
		interact_icon.position.y = icon_base_y
