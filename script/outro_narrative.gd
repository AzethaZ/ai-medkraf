extends Control

@export_file("*.tscn") var next_scene: String = "res://scene/Function/Intro/main_menu.tscn"
@export var char_delay: float = 0.04
@export var typing_sfx: AudioStream

@onready var text_label: Label = $TextLabel
@onready var interact_icon: Sprite2D = $InteractIcon
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var narratives: Array[String] = [
	"Danum mulai mengajak masyarakat menanam pohon dan membicarakan rencana pengembangan desa wisata.",
	"Seiring berjalannya waktu, Danum terus berusaha untuk memulihkan hutannya seperti sedia kala. Tentu perjuangannya hingga ke titik ini tidaklah mudah, ia masih harus menghadapi banyak rintangan dan hambatan dari berbagai pihak.",
	"Untungnya ia tidak sendirian. Masih banyak orang-orang yang memiliki tujuan yang sama dengannya, karena untuk mencapai sebuah perubahan yang besar diperlukan kekuatan yang sama besarnya juga.",
	"Beberapa tahun kemudian, perlahan wajah hutan itu mulai berubah. Pohon-pohon kembali tumbuh rimbun, dan desa wisata yang dikelola bersama masyarakat menjadi tempat belajar sekaligus menjaga alam.",
	"Dari tanah yang dulu terluka, tumbuh harapan baru—tempat manusia dan hutan kembali hidup berdampingan."
]

var current_index: int = 0
var is_typing: bool = false
var skip_requested: bool = false
var icon_tween: Tween


func _ready() -> void:
	# Hapus overlay hitam dari world_8 jika ada (latar outro_narrative sudah hitam)
	if get_tree().root.has_meta("world8_to_outro_fade"):
		var fade_layer := get_tree().root.get_meta("world8_to_outro_fade") as CanvasLayer
		get_tree().root.remove_meta("world8_to_outro_fade")
		if is_instance_valid(fade_layer):
			fade_layer.queue_free()

	if typing_sfx and sfx_player:
		sfx_player.stream = typing_sfx

	if interact_icon:
		interact_icon.visible = false
		_start_icon_pulse()

	_show_narrative(0)


func _unhandled_input(event: InputEvent) -> void:
	var advance_pressed: bool = (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("interact")
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER))
	)

	if advance_pressed:
		if is_typing:
			skip_requested = true
		else:
			_next_narrative()


func _show_narrative(index: int) -> void:
	current_index = index
	is_typing = true
	skip_requested = false

	if interact_icon:
		interact_icon.visible = false

	var full_text: String = narratives[current_index]
	text_label.text = full_text
	text_label.visible_characters = 0

	for i in range(full_text.length()):
		if skip_requested:
			break
		text_label.visible_characters = i + 1
		if sfx_player and sfx_player.stream and full_text[i] != " ":
			sfx_player.pitch_scale = randf_range(0.95, 1.05)
			sfx_player.play()
		await get_tree().create_timer(char_delay).timeout

	text_label.visible_characters = -1
	is_typing = false

	if interact_icon:
		interact_icon.visible = true


func _next_narrative() -> void:
	if current_index + 1 < narratives.size():
		_show_narrative(current_index + 1)
	else:
		_finish_outro()


func _finish_outro() -> void:
	set_process_unhandled_input(false)
	if interact_icon:
		interact_icon.visible = false

	var fade_tween := create_tween()
	fade_tween.tween_property(text_label, "modulate:a", 0.0, 1.0)
	await fade_tween.finished

	if next_scene != "" and ResourceLoader.exists(next_scene):
		get_tree().change_scene_to_file(next_scene)


func _start_icon_pulse() -> void:
	if not is_instance_valid(interact_icon):
		return
	icon_tween = create_tween().set_loops()
	icon_tween.tween_property(interact_icon, "modulate:a", 0.3, 0.55)
	icon_tween.tween_property(interact_icon, "modulate:a", 1.0, 0.55)
