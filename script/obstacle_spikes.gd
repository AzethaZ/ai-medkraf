extends Area2D

@export var move_speed: float = 200.0
@export var rotation_speed: float = 10.0

@onready var area_2d: Area2D = find_child("Area2D", true, false)
# Mencari node visual sprite di dalam obstacle
@onready var sprite = find_child("Sprite2D", true, false) if find_child("Sprite2D", true, false) else find_child("AnimatedSprite2D", true, false)
# Referensi node audio 2D (otomatis mengambil AudioStreamPlayer2D)
@onready var roll_sound: AudioStreamPlayer2D = find_child("AudioStreamPlayer2D", true, false) as AudioStreamPlayer2D


func _ready() -> void:
	# Hubungkan event jika area menabrak sesuatu
	if area_2d:
		area_2d.body_entered.connect(_on_body_entered)
	
	# Memutar audio positional 2D jika belum Autoplay
	if roll_sound and roll_sound.stream and not roll_sound.playing:
		roll_sound.play()


func _process(delta: float) -> void:
	# 1. Bergerak ke kiri mengikuti scroll layar
	position.x -= move_speed * delta

	# 2. Memutar sprite terus-menerus (berlawanan arah jarum jam agar efek menggelinding ke kiri pas)
	if sprite:
		sprite.rotation -= rotation_speed * delta
	else:
		# Jika tidak ketemu node sprite khusus, putar node utama
		rotation -= rotation_speed * delta

	# 3. Hapus dari memori jika sudah keluar jauh dari layar sebelah kiri
	if position.x < -800:
		var world = get_tree().current_scene
		if world and world.has_method("increment_obstacle_cleared"):
			world.increment_obstacle_cleared()
			
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Cek apakah yang menabrak adalah Player (Danum)
	if body.is_in_group("player") or body.name == "Player":
		var world = get_tree().current_scene
		if world and world.has_method("on_player_hit_obstacle"):
			world.on_player_hit_obstacle()
		queue_free() # Hapus trenggiling setelah menabrak Danum
