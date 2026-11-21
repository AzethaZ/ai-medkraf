extends CanvasLayer

@onready var notification_box: PanelContainer = $NotificationBox
@onready var icon_rect: TextureRect = $NotificationBox/HBoxContainer/Icon
@onready var title_label: Label = $NotificationBox/HBoxContainer/TitleLabel

var tween: Tween
var sfx_player: AudioStreamPlayer
var default_icon: Texture2D

@export var margin_right: float = 0.0
@export var slide_duration: float = 0.4
@export var display_time: float = 3.0

@export_group("Quest SFX")
@export var quest_start_sfx: AudioStream
@export var quest_complete_sfx: AudioStream
@export var sfx_volume: float = 0.0

@export_group("Quest Icons")
@export var quest_icons: Dictionary[String, Texture2D] = {
	"quest_ayam_1": null,
	"quest_ayam_3": null,
	"quest_kopi_1": null
}

func _ready() -> void:
	if icon_rect:
		default_icon = icon_rect.texture

	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = sfx_volume
	add_child(sfx_player)

	reset_position_offscreen()

	if QuestManager:
		QuestManager.quest_status_changed.connect(_on_quest_status_changed)

func reset_position_offscreen() -> void:
	notification_box.reset_size()
	var screen_width := get_viewport().get_visible_rect().size.x

	notification_box.position.x = screen_width + 10.0
	notification_box.modulate.a = 0.0

func _on_quest_status_changed(quest_id: String, new_status: String) -> void:
	if not QuestManager.quests.has(quest_id):
		return

	var quest_data: Dictionary = QuestManager.quests[quest_id]
	var quest_title: String = quest_data["title"]
	var collected: int = quest_data.get("collected_count", 0)
	var target: int = quest_data.get("target_count", 1)
	var custom_icon: Texture2D = quest_icons.get(quest_id, null)

	if new_status == "ACTIVE":
		if collected > 0:
			show_notification("%s (%d/%d)" % [quest_title, collected, target], custom_icon)
		else:
			_play_sfx(quest_start_sfx)
			show_notification("New Quest: " + quest_title, custom_icon)
	elif new_status == "READY_TO_SUBMIT":
		show_notification("%s (%d/%d)" % [quest_title, collected, target], custom_icon)
	elif new_status == "COMPLETED":
		_play_sfx(quest_complete_sfx)
		show_notification("Quest Completed: " + quest_title, custom_icon)

func _play_sfx(stream: AudioStream) -> void:
	if stream and sfx_player:
		sfx_player.stream = stream
		sfx_player.volume_db = sfx_volume
		sfx_player.play()

func show_notification(text: String, custom_icon: Texture2D = null) -> void:
	title_label.text = text

	if icon_rect:
		if custom_icon != null:
			icon_rect.texture = custom_icon
		else:
			icon_rect.texture = default_icon

	notification_box.reset_size()

	var screen_width := get_viewport().get_visible_rect().size.x
	var target_x := screen_width - notification_box.size.x - margin_right
	var start_x := screen_width + 10.0

	if tween and tween.is_running():
		tween.kill()

	notification_box.position.x = start_x
	notification_box.modulate.a = 1.0

	tween = create_tween().set_parallel(false)

	tween.tween_property(notification_box, "position:x", target_x, slide_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_interval(display_time)

	tween.tween_property(notification_box, "position:x", start_x, slide_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(notification_box, "modulate:a", 0.0, slide_duration)
