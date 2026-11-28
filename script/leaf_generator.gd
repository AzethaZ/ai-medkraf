@tool
extends Node2D

@export_group("Leaf Textures")
@export var leaf_textures: Array[Texture2D] = [
	preload("res://assets/animation/daun_1.png"),
	preload("res://assets/animation/daun_2.png"),
	preload("res://assets/animation/daun_3.png")
]

@export_group("Spawn Area & Timing")
@export var spawn_width: float = 1200.0:
	set(value):
		spawn_width = value
		queue_redraw()
@export var spawn_interval_min: float = 1.2 # Sebelumnya 0.45
@export var spawn_interval_max: float = 2.4 # Sebelumnya 1.0
@export var max_active_leaves: int = 8      # Sebelumnya 24

@export_group("Fall & Wind Motion")
@export var fall_distance_min: float = 240.0:
	set(value):
		fall_distance_min = value
		queue_redraw()
@export var fall_distance_max: float = 340.0:
	set(value):
		fall_distance_max = value
		queue_redraw()
@export var fall_duration_min: float = 6.5
@export var fall_duration_max: float = 9.5
@export var wind_drift_x: float = -12.0 # Geser angin tipis saja
@export var sway_amplitude: float = 8.0 # Ayunan kanan-kiri sempit & lembut

var _timer: float = 0.0
var _active_leaves: int = 0

func _draw() -> void:
	# Garis bantu visual hanya muncul di editor (hilang otomatis saat game Play)
	if Engine.is_editor_hint():
		var half_w := spawn_width * 0.5
		# Garis atas = titik muncul daun
		draw_line(Vector2(-half_w, 0.0), Vector2(half_w, 0.0), Color(0.3, 1.0, 0.4, 0.9), 2.0)
		# Kotak area = jangkauan jatuh daun
		var preview_rect := Rect2(-half_w, 0.0, spawn_width, fall_distance_max)
		draw_rect(preview_rect, Color(0.3, 1.0, 0.4, 0.12), true)
		draw_rect(preview_rect, Color(0.3, 1.0, 0.4, 0.5), false, 1.5)

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_timer = randf_range(0.3, spawn_interval_max)
	for i in range(2):
		_spawn_falling_leaf(true)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(spawn_interval_min, spawn_interval_max)
		if _active_leaves < max_active_leaves:
			_spawn_falling_leaf(false)

func _spawn_falling_leaf(prewarm: bool = false) -> void:
	if leaf_textures.is_empty():
		return

	var tex: Texture2D = leaf_textures.pick_random()
	if not tex:
		return

	var leaf := Sprite2D.new()
	leaf.texture = tex
	leaf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leaf.z_index = 15

	var start_x := randf_range(-spawn_width * 0.5, spawn_width * 0.5)
	var start_y := randf_range(0.0, fall_distance_min * 0.5) if prewarm else 0.0
	leaf.position = Vector2(start_x, start_y)

	var s := randf_range(0.75, 1.0)
	leaf.scale = Vector2(s, s)
	leaf.flip_h = randf() > 0.5
	var base_rot := randf_range(-0.15, 0.15)
	leaf.rotation = base_rot
	leaf.modulate.a = 0.0 if not prewarm else 0.85

	add_child(leaf)
	_active_leaves += 1

	var duration := randf_range(fall_duration_min, fall_duration_max)
	var fall_dist := randf_range(fall_distance_min, fall_distance_max)
	var end_y := start_y + fall_dist

	# Geser angin tipis ke agak kiri (-12 s.d. -25 px) + ayunan kanan-kiri sempit (6 s.d. 11 px)
	var drift_left := -randf_range(12.0, 25.0)
	var sway_amp := randf_range(6.0, 11.0) * (-1.0 if randf() > 0.5 else 1.0)
	var sway_cycles := randf_range(1.5, 2.2) # Jumlah ayunan kanan-kiri selama jatuh

	var tween := create_tween().set_parallel(true)

	# 1. Turun pelan-pelan
	tween.tween_property(leaf, "position:y", end_y, duration)\
		.set_trans(Tween.TRANS_LINEAR)

	# 2. Ayunan kanan-kiri pakai sin() (selalu mulai dari 0, jadi tidak akan mental)
	tween.tween_method(func(t: float):
		if is_instance_valid(leaf):
			var wave := sin(t * TAU * sway_cycles)
			leaf.position.x = start_x + (drift_left * t) + (wave * sway_amp)
			leaf.rotation = base_rot + (wave * 0.25)
	, 0.0, 1.0, duration)

	# 3. Muncul pelan (fade-in) & menghilang pelan (fade-out)
	if not prewarm:
		tween.tween_property(leaf, "modulate:a", 0.9, 0.8)
	tween.tween_property(leaf, "modulate:a", 0.0, 1.2)\
		.set_delay(maxf(0.1, duration - 1.2))

	tween.chain().tween_callback(func():
		_active_leaves = max(0, _active_leaves - 1)
		if is_instance_valid(leaf):
			leaf.queue_free()
	)
