extends Area2D

@onready var interact_icon: Sprite2D = $InteractIcon if has_node("InteractIcon") else null
@onready var dialogue_pivot: Node2D = $DialoguePivot if has_node("DialoguePivot") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

var is_player_in_range: bool = false
var is_dialogue_active: bool = false
var has_talked: bool = false # Status penanda apakah sudah pernah diajak bicara
var tween_hover: Tween

# 1. DIALOG UTAMA (Pertama kali bicara)
var main_dialogue_data: Array[Dictionary] = [
	{
		"speaker": "npc",
		"text": "Eh, Danum? Kenapa mukanya cemberut?"
	},
	{
		"speaker": "mc",
		"text": "Orang-orang desa tidak ada yang mau dengar, Paman. Mereka meyalakan api padahal hutan ini kan lagi kering sekali."
	},
	{
		"speaker": "npc",
		"text": "Sebenarnya kamu tidak sepenuhnya salah, Danum. Paman juga lagi khawatir..."
	},
	{
		"speaker": "npc",
		"text": "Tadi Paman lihat ada dua orang asing masuk ke arah hutan dalam. Katanya mau survei lahan, tapi mereka merokok sembarangan."
	},
	{
		"speaker": "mc",
		"text": "Dua orang asing? Bawa rokok?!"
	},
	{
		"speaker": "npc",
		"text": "Iya. Paman mau susul mereka tapi masih ada urusan. Kamu jangan ke arah hutan dalam ya, bahaya kalau ketemu orang luar yang tidak kita kenal."
	}
]

# 2. DIALOG SINGKAT (Bicara kedua kali dan seterusnya)
var repeat_dialogue_data: Array[Dictionary] = [
	{
		"speaker": "npc",
		"text": "Jangan ke area hutan dalam sendirian ya Danum, bahaya kalau ketemu dua orang asing itu."
	}
]

func _ready() -> void:
	if interact_icon:
		interact_icon.visible = false
		start_hover_animation()
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func start_hover_animation() -> void:
	if not interact_icon:
		return
		
	if tween_hover and tween_hover.is_running():
		tween_hover.kill()
		
	tween_hover = create_tween().set_loops()
	tween_hover.tween_property(interact_icon, "position:y", -4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
	tween_hover.tween_property(interact_icon, "position:y", 4.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		is_player_in_range = true
		if interact_icon and not is_dialogue_active:
			interact_icon.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		is_player_in_range = false
		if interact_icon:
			interact_icon.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_player_in_range and not is_dialogue_active:
		if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			start_npc_dialogue()

func start_npc_dialogue() -> void:
	is_dialogue_active = true
	if interact_icon:
		interact_icon.visible = false
	
	# Turn NPC menghadap Player
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and sprite:
		if player.global_position.x < global_position.x:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
		
	if DialogueManager:
		if DialogueManager.has_signal("dialogue_finished"):
			if not DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
				DialogueManager.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
		
		# Pilih dialog berdasarkan status has_talked
		var current_data = main_dialogue_data if not has_talked else repeat_dialogue_data
		DialogueManager.start_dialogue(current_data, self)

func _on_dialogue_finished() -> void:
	is_dialogue_active = false
	has_talked = true # Tandai bahwa NPC sudah pernah diajak bicara
	
	if is_player_in_range and interact_icon:
		interact_icon.visible = true
