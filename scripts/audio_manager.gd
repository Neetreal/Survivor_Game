extends Node
## Менеджер звука (автозагрузка AudioManager): пул плееров для полифонии
## и защита от спама одинаковых звуков (попадания, кристаллы).

var sounds: Dictionary = {
	"shoot": preload("res://sounds/shoot.wav"),
	"hit": preload("res://sounds/hit.wav"),
	"enemy_die": preload("res://sounds/enemy_die.wav"),
	"gem": preload("res://sounds/gem.wav"),
	"levelup": preload("res://sounds/levelup.wav"),
	"nova": preload("res://sounds/nova.wav"),
	"lightning": preload("res://sounds/lightning.wav"),
	"explosion": preload("res://sounds/explosion.wav"),
	"hurt": preload("res://sounds/hurt.wav"),
	"chest": preload("res://sounds/chest.wav"),
	"victory": preload("res://sounds/victory.wav"),
	"gameover": preload("res://sounds/gameover.wav"),
	"click": preload("res://sounds/click.wav"),
	"boomerang": preload("res://sounds/boomerang.wav"),
}

const MIN_INTERVALS: Dictionary = {"hit": 80, "gem": 60, "shoot": 70, "enemy_die": 60}

## Музыка: три зацикленных трека (меню, бой, босс).
var music_tracks: Dictionary = {
	"menu": preload("res://sounds/music_menu.wav"),
	"battle": preload("res://sounds/music_battle.wav"),
	"boss": preload("res://sounds/music_boss.wav"),
}
var music_player: AudioStreamPlayer
var current_track: String = ""
var music_volume_db: float = -15.0
var fade_tween: Tween = null

var players: Array = []
var last_played: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Звуки работают и на паузе (клики, уровень)
	for i in range(12):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	Records.apply_volume() # Громкость из настроек

func play_music(track: String, fade: float = 0.6) -> void:
	# Смена трека с плавным затуханием — без щелчков на стыке.
	if not music_tracks.has(track):
		return
	if current_track == track and music_player.playing:
		return
	current_track = track
	var stream: AudioStream = music_tracks[track]
	_make_looping(stream)
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if music_player.playing and fade > 0.0:
		fade_tween = create_tween()
		fade_tween.tween_property(music_player, "volume_db", -40.0, fade * 0.5)
		fade_tween.tween_callback(_start_music.bind(stream))
		fade_tween.tween_property(music_player, "volume_db", music_volume_db, fade * 0.5)
	else:
		_start_music(stream)
		music_player.volume_db = music_volume_db

func _start_music(stream: AudioStream) -> void:
	music_player.stream = stream
	music_player.volume_db = -40.0
	music_player.play()

func stop_music(fade: float = 0.8) -> void:
	current_track = ""
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if not music_player.playing:
		return
	fade_tween = create_tween()
	fade_tween.tween_property(music_player, "volume_db", -50.0, fade)
	fade_tween.tween_callback(music_player.stop)

func _make_looping(stream: AudioStream) -> void:
	# Импортированный WAV по умолчанию не зациклен — включаем цикл вручную.
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))

func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds.has(sound_name):
		return
	var now: int = Time.get_ticks_msec()
	var interval: int = int(MIN_INTERVALS.get(sound_name, 0))
	if last_played.has(sound_name) and now - int(last_played[sound_name]) < interval:
		return
	last_played[sound_name] = now
	for p in players:
		if not p.playing:
			p.stream = sounds[sound_name]
			p.volume_db = volume_db
			p.pitch_scale = pitch * randf_range(0.96, 1.04)
			p.play()
			return
