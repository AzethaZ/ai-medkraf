extends CanvasLayer

@onready var notification_box: PanelContainer = $NotificationBox
@onready var title_label: Label = $NotificationBox/HBoxContainer/TitleLabel

var tween: Tween

# Ubah margin_right menjadi 0.0 agar menempel di pinggir kanan layar
@export var margin_right: float = 0.0 
@export var slide_duration: float = 0.4 
@export var display_time: float = 3

func _ready() -> void:
	reset_position_offscreen()
	
	if QuestManager:
		QuestManager.quest_status_changed.connect(_on_quest_status_changed)

func reset_position_offscreen() -> void:
	notification_box.reset_size()
	var screen_width = get_viewport().get_visible_rect().size.x
	
	notification_box.position.x = screen_width + 10.0
	notification_box.modulate.a = 0.0

func _on_quest_status_changed(quest_id: String, new_status: String) -> void:
	var quest_title = QuestManager.quests[quest_id]["title"]
	
	if new_status == "ACTIVE":
		show_notification("New Quest: " + quest_title)
	elif new_status == "COMPLETED":
		show_notification("Quest Completed: " + quest_title)

func show_notification(text: String) -> void:
	title_label.text = text
	
	# Reset ukuran container agar pas dengan panjang teks
	notification_box.reset_size()
	
	var screen_width = get_viewport().get_visible_rect().size.x
	
	# Target posisi X pas di ujung kanan layar (Lebar Layar - Lebar Box)
	var target_x = screen_width - notification_box.size.x - margin_right
	var start_x = screen_width + 10.0

	if tween and tween.is_running():
		tween.kill()

	notification_box.position.x = start_x
	notification_box.modulate.a = 1.0

	tween = create_tween().set_parallel(false)
	
	# Slide in ke pinggir layar
	tween.tween_property(notification_box, "position:x", target_x, slide_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	tween.tween_interval(display_time)
	
	# Slide out kembali ke luar layar
	tween.tween_property(notification_box, "position:x", start_x, slide_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(notification_box, "modulate:a", 0.0, slide_duration)
