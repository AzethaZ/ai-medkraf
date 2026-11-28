extends Control

@export_file("*.tscn") var next_cutscene_scene: String = "res://scene/Function/intro_cutscene.tscn"
@export var tutorial_duration: float = 3.5

@onready var text_label: Label = $TextLabel
@onready var background: ColorRect = $Background
@onready var interact_icon: Sprite2D = $InteractIcon if has_node("InteractIcon") else null
@onready var tutorial_image: TextureRect = $TutorialImage if has_node("TutorialImage") else null

# Referensi Node Audio Player
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer if has_node("SFXPlayer") else null
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer if has_node("BGMPlayer") else null

# Kalimat narasi pembuka (sama persis seperti sebelumnya)
var story_sentences: Array[String] = [
	"Hutan telah memberi kehidupan dan sumber daya bagi manusia.",
	"Namun keserakahan merusaknya lewat eksploitasi dan kebakaran keji.",
	"Di tengah kehancuran itu...",
	"Secercah harapan tersisa pada mereka yang peduli melangkah..."
]

var current_sentence_index: int = 0
var is_typing: bool = false
var is_transitioning: bool = false
var is_showing_tutorial: bool = false

var hover_tween: Tween = null
var fade_tween: Tween = null
var initial_icon_y: float = 0.0

# Kecepatan muncul per-huruf (0.04 detik = sangat nyaman/pelan)
@export var char_delay: float = 0.04

func _ready() -> void:
	if background:
		background.modulate.a = 1.0

	if text_label:
		text_label.text = ""
		text_label.modulate.a = 0.0

	if interact_icon:
		initial_icon_y = interact_icon.position.y
		interact_icon.visible = false

	if tutorial_image:
		tutorial_image.visible = true
		tutorial_image.modulate.a = 1.0

	# Putar BGM sejak awal narasi dimulai
	if bgm_player and bgm_player.stream and not bgm_player.playing:
		bgm_player.play()

	# Buka tirai hitam global dari MainMenu dengan mulus
	await SceneTransition.fade_in(0.8)

	# Tampilkan gambar tutorial selama tutorial_duration sebelum masuk ke kalimat pertama
	if tutorial_image:
		is_showing_tutorial = true
		await get_tree().create_timer(tutorial_duration).timeout

		var tut_fade := create_tween()
		tut_fade.tween_property(tutorial_image, "modulate:a", 0.0, 0.45)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tut_fade.finished
		tutorial_image.visible = false
		is_showing_tutorial = false

	_show_sentence(current_sentence_index)

# Animasi ketik per-huruf + SFX type halus
func _show_sentence(index: int) -> void:
	if index >= story_sentences.size():
		_go_to_cutscene()
		return

	_hide_interact_icon()

	var full_text: String = story_sentences[index]

	text_label.text = full_text
	text_label.visible_characters = 0
	text_label.modulate.a = 1.0

	is_typing = true

	for i in range(1, full_text.length() + 1):
		if not is_typing:
			break

		text_label.visible_characters = i
		var current_char := full_text[i - 1]

		# Bunyikan SFX per huruf (mengabaikan spasi)
		if current_char != " " and sfx_player and sfx_player.stream:
			sfx_player.pitch_scale = randf_range(0.97, 1.03)
			sfx_player.play()

		# Jeda waktu ketik antar huruf
		await get_tree().create_timer(char_delay).timeout

	# Teks selesai ditampilkan penuh
	if is_typing:
		text_label.visible_characters = -1
		is_typing = false
		_show_interact_icon()

func _next_sentence() -> void:
	if is_transitioning or is_showing_tutorial:
		return

	# JIKA MASIH MENGETIK: Tekan tombol interact untuk langsung tampilkan sisa teks
	if is_typing:
		is_typing = false
		text_label.visible_characters = -1
		_show_interact_icon()
		return

	# JIKA TEKS SUDAH PENUH: Fade-out teks lalu lanjut ke kalimat berikutnya
	_hide_interact_icon()

	if fade_tween and fade_tween.is_running():
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(text_label, "modulate:a", 0.0, 0.25)
	await fade_tween.finished

	current_sentence_index += 1
	_show_sentence(current_sentence_index)

func _unhandled_input(event: InputEvent) -> void:
	if is_showing_tutorial:
		return
	if not is_transitioning and ((event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")) or (event is InputEventKey and event.pressed and not event.echo)):
		get_viewport().set_input_as_handled()
		_next_sentence()

func _show_interact_icon() -> void:
	if not interact_icon:
		return

	interact_icon.visible = true
	interact_icon.modulate.a = 1.0

	if hover_tween and hover_tween.is_running():
		hover_tween.kill()

	hover_tween = create_tween().set_loops()
	hover_tween.tween_property(interact_icon, "position:y", initial_icon_y - 3.0, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover_tween.tween_property(interact_icon, "position:y", initial_icon_y + 3.0, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _hide_interact_icon() -> void:
	if not interact_icon:
		return

	if hover_tween and hover_tween.is_running():
		hover_tween.kill()

	interact_icon.visible = false
	interact_icon.position.y = initial_icon_y

func _go_to_cutscene() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	_hide_interact_icon()

	if fade_tween and fade_tween.is_running():
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(text_label, "modulate:a", 0.0, 0.3)
	await fade_tween.finished

	await SceneTransition.fade_out(0.7)
	get_tree().change_scene_to_file(next_cutscene_scene)
