extends Node

var ambience_player: AudioStreamPlayer
var bgm_player: AudioStreamPlayer

func _ready() -> void:
	# Buat 2 pemutar audio otomatis di Autoload
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "AmbiencePlayer"
	add_child(ambience_player)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	add_child(bgm_player)

# MEMUTAR MUSIK & AMBIENCE (DENGAN EFEK FADE IN)
func play_world_audio(ambience_stream: AudioStream, bgm_stream: AudioStream, target_ambience_db: float = -8.0, target_bgm_db: float = -12.0) -> void:
	if ambience_stream:
		ambience_player.stream = ambience_stream
		ambience_player.volume_db = -80.0
		ambience_player.play()
		var tween_amb = create_tween()
		tween_amb.tween_property(ambience_player, "volume_db", target_ambience_db, 1.5)

	if bgm_stream:
		bgm_player.stream = bgm_stream
		bgm_player.volume_db = -80.0
		bgm_player.play()
		var tween_bgm = create_tween()
		tween_bgm.tween_property(bgm_player, "volume_db", target_bgm_db, 1.5)

# FADE OUT KEDUA AUDIO SECARA PELAN (TETAP JALAN MESKI SCENE BERPINDAH)
func fade_out_audio(duration: float = 2.5) -> void:
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if ambience_player.playing:
		tween.tween_property(ambience_player, "volume_db", -80.0, duration)

	if bgm_player.playing:
		tween.tween_property(bgm_player, "volume_db", -80.0, duration)

	await tween.finished
	
	# Hentikan audio setelah pekat hening
	if ambience_player.volume_db <= -79.0:
		ambience_player.stop()
	if bgm_player.volume_db <= -79.0:
		bgm_player.stop()
