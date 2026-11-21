extends CharacterBody2D

@export var speed: float = 35.0                    # Kecepatan jalan ayam
@export var min_idle_time: float = 2.0             # Waktu minimal diam (idle)
@export var max_idle_time: float = 5.0             # Waktu maksimal diam (idle)
@export var min_walk_time: float = 3.0             # Waktu minimal berjalan (jarak jauh)
@export var max_walk_time: float = 7.0             # Waktu maksimal berjalan

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

enum State { IDLE, WALK }
var current_state: State = State.IDLE
var move_direction: float = 0.0
var state_timer: float = 0.0

func _ready() -> void:
	randomize()
	_change_to_idle()

func _physics_process(delta: float) -> void:
	# Kurangi timer state
	state_timer -= delta
	if state_timer <= 0.0:
		_decide_next_state()

	# Atur pergerakan horizontal berdasarkan state saat ini
	if current_state == State.WALK:
		velocity.x = move_direction * speed
		if animated_sprite:
			animated_sprite.play("walk")
			if move_direction != 0:
				animated_sprite.flip_h = move_direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		if animated_sprite:
			animated_sprite.play("idle")

	# Kunci posisi Y agar ayam tidak akan pernah jatuh ke bawah
	velocity.y = 0.0
	move_and_slide()

func _decide_next_state() -> void:
	if current_state == State.IDLE:
		var choice = randi() % 3
		if choice == 0:
			move_direction = -1.0 # Jalan ke kiri
			current_state = State.WALK
			state_timer = randf_range(min_walk_time, max_walk_time)
		elif choice == 1:
			move_direction = 1.0  # Jalan ke kanan
			current_state = State.WALK
			state_timer = randf_range(min_walk_time, max_walk_time)
		else:
			_change_to_idle()
	else:
		_change_to_idle()

func _change_to_idle() -> void:
	current_state = State.IDLE
	move_direction = 0.0
	state_timer = randf_range(min_idle_time, max_idle_time)
