extends CharacterBody2D

@export var move_speed: float = 25.0
@export var walk_time_min: float = 1.0
@export var walk_time_max: float = 3.0
@export var idle_time_min: float = 1.5
@export var idle_time_max: float = 4.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: float = 0.0
var is_moving: bool = false
var timer: float = 0.0

func _ready() -> void:
	# Matikan collision fisik agar tidak menyangkut di NPC/Player
	collision_layer = 0
	collision_mask = 0
	choose_next_action()

func _physics_process(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		choose_next_action()

	if is_moving:
		velocity.x = direction * move_speed
		if animated_sprite:
			animated_sprite.flip_h = (direction < 0)
			if animated_sprite.sprite_frames.has_animation("walk"):
				animated_sprite.play("walk")
	else:
		velocity.x = 0
		if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")

	move_and_slide()

func choose_next_action() -> void:
	# Pilih acak: diam atau jalan
	if randf() > 0.4:
		is_moving = true
		direction = -1.0 if randf() > 0.5 else 1.0
		timer = randf_range(walk_time_min, walk_time_max)
	else:
		is_moving = false
		timer = randf_range(idle_time_min, idle_time_max)
