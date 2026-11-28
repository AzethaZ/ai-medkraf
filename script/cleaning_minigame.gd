extends Control

signal cleaning_completed

@export var sweep_speed: float = 1.35
@export var hits_required: int = 3

@export_group("Audio SFX")
@export var hit_sfx: AudioStream # Suara saat kena kotak target (1/3 & 2/3)
@export var complete_sfx: AudioStream # Suara saat pukulan ke-3 berhasil & selesai bersih (opsional)
@export var miss_sfx: AudioStream # Suara saat meleset / gagal
@export var sfx_volume_db: float = 0.0

@export_group("Screen Fade")
@export var fade_color: Color = Color.BLACK # Bisa diganti Color.WHITE jika ingin fade putih
@export var fade_in_duration: float = 0.25 # Durasi layar menggelap
@export var fade_hold_duration: float = 0.12 # Jeda singkat saat layar penuh tertutup
@export var fade_out_duration: float = 0.25 # Durasi layar kembali terang

@onready var center_container: CenterContainer = $CenterContainer
@onready var bar_wrapper: Control = $CenterContainer/BarWrapper
@onready var bar_bg: NinePatchRect = $CenterContainer/BarWrapper/BarBG
@onready var green_zone: NinePatchRect = $CenterContainer/BarWrapper/BarBG/GreenZone
@onready var needle: TextureRect = $CenterContainer/BarWrapper/BarBG/Needle

var progress: float = 0.0
var direction: float = 1.0
var hits_count: int = 0
var is_active: bool = true
var sfx_player: AudioStreamPlayer = null
var miss_tween: Tween = null
var white_flash_mat: ShaderMaterial = null
var fade_rect: ColorRect = null


func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = sfx_volume_db
	add_child(sfx_player)

	# Buat overlay ColorRect full layar untuk transisi fade saat selesai
	fade_rect = ColorRect.new()
	fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)

	# Buat material shader siluet putih solid untuk efek miss
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
	void fragment() {
		vec4 tex_color = texture(TEXTURE, UV);
		COLOR = vec4(mix(tex_color.rgb, vec3(1.0), flash_amount), tex_color.a);
	}
	"""
	white_flash_mat = ShaderMaterial.new()
	white_flash_mat.shader = shader

	bar_bg.material = white_flash_mat
	green_zone.material = white_flash_mat
	needle.material = white_flash_mat

	progress = 0.0
	direction = 1.0
	hits_count = 0
	needle.position.x = 0.0
	_move_green_zone_randomly()


func _process(delta: float) -> void:
	if not is_active:
		return

	progress += direction * sweep_speed * delta
	if progress >= 1.0:
		progress = 1.0
		direction = -1.0
	elif progress <= 0.0:
		progress = 0.0
		direction = 1.0

	var needle_width: float = needle.size.x * needle.scale.x
	var max_x: float = max(0.0, bar_wrapper.size.x - needle_width)
	needle.position.x = progress * max_x


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_check_hit()


func _move_green_zone_randomly() -> void:
	var padding: float = 6.0
	var zone_width: float = green_zone.size.x * green_zone.scale.x
	var min_x: float = padding
	var max_x: float = max(min_x, bar_wrapper.size.x - zone_width - padding)

	var next_x: float = randf_range(min_x, max_x)
	if abs(next_x - green_zone.position.x) < zone_width and (max_x - min_x) > zone_width * 1.5:
		if green_zone.position.x < (min_x + max_x) * 0.5:
			next_x = randf_range((min_x + max_x) * 0.5, max_x)
		else:
			next_x = randf_range(min_x, (min_x + max_x) * 0.5)

	green_zone.position.x = next_x


func _check_hit() -> void:
	var needle_width: float = needle.size.x * needle.scale.x
	var zone_width: float = green_zone.size.x * green_zone.scale.x

	var needle_center: float = needle.position.x + (needle_width * 0.5)
	var zone_start: float = green_zone.position.x
	var zone_end: float = green_zone.position.x + zone_width

	if needle_center >= zone_start and needle_center <= zone_end:
		hits_count += 1
		if hits_count >= hits_required:
			_play_success_fade_sequence()
		else:
			_play_sfx(hit_sfx)
			_move_green_zone_randomly()
	else:
		_play_sfx(miss_sfx)
		_play_miss_effect()


func _play_success_fade_sequence() -> void:
	is_active = false
	var final_sfx: AudioStream = complete_sfx if complete_sfx != null else hit_sfx
	_play_sfx(final_sfx)

	# Sembunyikan bar QTE agar hanya efek fade layar yang terlihat
	center_container.visible = false

	# 1. Fade layar menjadi tertutup penuh (alpha 0.0 -> 1.0)
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, fade_in_duration)
	await fade_tween.finished

	# 2. Tahan sejenak sambil menjalankan perubahan visual bersih di balik layar
	await get_tree().create_timer(fade_hold_duration).timeout
	cleaning_completed.emit()

	# 3. Fade layar kembali terbuka (alpha 1.0 -> 0.0)
	var unfade_tween := create_tween()
	unfade_tween.tween_property(fade_rect, "color:a", 0.0, fade_out_duration)
	await unfade_tween.finished

	# 4. Hapus CanvasLayer pembungkus & kembalikan kontrol gerak pemain
	var parent_layer := get_parent()
	if parent_layer is CanvasLayer:
		parent_layer.queue_free()
	else:
		queue_free()


func _play_miss_effect() -> void:
	if miss_tween and miss_tween.is_valid():
		miss_tween.kill()

	var base_x: float = bar_wrapper.position.x

	white_flash_mat.set_shader_parameter("flash_amount", 1.0)

	miss_tween = create_tween()
	miss_tween.tween_property(bar_wrapper, "position:x", base_x - 7.0, 0.03)
	miss_tween.tween_property(bar_wrapper, "position:x", base_x + 7.0, 0.03)
	miss_tween.tween_property(bar_wrapper, "position:x", base_x - 5.0, 0.03)
	miss_tween.tween_property(bar_wrapper, "position:x", base_x + 5.0, 0.03)
	miss_tween.tween_property(bar_wrapper, "position:x", base_x - 2.0, 0.025)
	miss_tween.tween_property(bar_wrapper, "position:x", base_x, 0.025)
	miss_tween.parallel().tween_method(
		func(val: float): white_flash_mat.set_shader_parameter("flash_amount", val),
		1.0, 0.0, 0.12
	)


func _play_sfx(stream: AudioStream) -> void:
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()
