extends Area2D

# Diisi path scene cutscene ke-2 (Cutscene Bakar Hutan)
@export_file("*.tscn") var next_cutscene: String = "res://scene/Function/cutscene_hutan_1.tscn"

@onready var interact_icon: Sprite2D = $InteractIcon # Sesuaikan jika nama nodenya berbeda
@onready var sprite_bush: Sprite2D = $Sprite2D2 # Sesuai dengan node sprite semak di editor
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D # Pastikan node AudioStreamPlayer2D ada di dalam Area2D

var is_player_inside: bool = false
var has_been_triggered: bool = false
var hover_tween: Tween
var bush_tween: Tween

func _ready() -> void:
	if interact_icon:
		interact_icon.visible = false
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 1. Jalankan animasi goyang kresek-kresek semak
	start_bush_swaying()
	
	# 2. Mulai putar audio semak secara looping otomatis
	if audio_player and not audio_player.playing:
		audio_player.play()

# --- ANIMASI GOYANG SEMAK (KRESEK-KRESEK LALU DIAM) ---
func start_bush_swaying() -> void:
	if not sprite_bush:
		return
		
	# Buat tween looping untuk efek goyang kresek-kresek lalu jeda
	bush_tween = create_tween().set_loops()
	
	# 1. Putar audio tepat pas di awal semak mulai bergetar
	if audio_player:
		bush_tween.tween_callback(audio_player.play)
	
	# 2. Fase Bergetar Cepat (Kresek-kresek)
	for i in range(3):
		bush_tween.tween_property(sprite_bush, "rotation_degrees", 2.5, 0.08).set_trans(Tween.TRANS_LINEAR)
		bush_tween.tween_property(sprite_bush, "rotation_degrees", -2.5, 0.08).set_trans(Tween.TRANS_LINEAR)
		
	# Kembalikan ke posisi normal dengan cepat
	bush_tween.tween_property(sprite_bush, "rotation_degrees", 0.0, 0.1)
	
	# 3. Hentikan audio agar tidak berbunyi saat jeda
	if audio_player:
		bush_tween.tween_callback(audio_player.stop)
	
	# 4. Fase Diam / Jeda selama 2 detik (Suara dan semak sama-sama diam)
	bush_tween.tween_interval(2.0)

# --- ANIMASI HOVER IKON INTERAKSI ---
func start_hover_animation() -> void:
	if not interact_icon:
		return
		
	hover_tween = create_tween().set_loops()
	hover_tween.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
	hover_tween.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)

func stop_hover_animation() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and not has_been_triggered and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		trigger_bakar_hutan_cutscene()

func trigger_bakar_hutan_cutscene() -> void:
	has_been_triggered = true
	stop_hover_animation()
	
	if interact_icon:
		interact_icon.visible = false
		
	# Update stage cerita ke GameManager
	if GameManager:
		GameManager.advance_story(GameManager.StoryStep.CUTSCENE_HUTAN_1)
		
	if GameManager and GameManager.has_method("_change_world"):
		GameManager.call_deferred("_change_world", next_cutscene)
	else:
		get_tree().change_scene_to_file(next_cutscene)

func _on_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.name == "Player") and not has_been_triggered:
		is_player_inside = true
		if interact_icon:
			interact_icon.visible = true
			start_hover_animation()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_inside = false
		stop_hover_animation()
		if interact_icon:
			interact_icon.visible = false
