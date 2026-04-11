extends Node

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const _MAX_SFX_CHANNELS := 8

var _audio_table: Dictionary = {}

func _ready() -> void:
	_ensure_buses()

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"Music"
	add_child(_bgm_player)

	for i in _MAX_SFX_CHANNELS:
		var ch := AudioStreamPlayer.new()
		ch.bus = &"SFX"
		add_child(ch)
		_sfx_players.append(ch)

	_register_defaults()
	load_volume_settings()

func _ensure_buses() -> void:
	if AudioServer.get_bus_index(&"Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, &"Music")
		AudioServer.set_bus_send(AudioServer.get_bus_index(&"Music"), &"Master")
	if AudioServer.get_bus_index(&"SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, &"SFX")
		AudioServer.set_bus_send(AudioServer.get_bus_index(&"SFX"), &"Master")

func _register_defaults() -> void:
	# Populate once real assets exist:
	# register_audio("home_theme", "res://audio/bgm/home_theme.ogg")
	# register_audio("menu_move",  "res://audio/sfx/menu_move.wav")
	# register_audio("menu_confirm","res://audio/sfx/menu_confirm.wav")
	pass

## Register an audio stream by key so it can be played by name.
func register_audio(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_audio_table[key] = load(path)
	else:
		push_warning("Audio path not found for key '%s': %s" % [key, path])

# ---- BGM ----

func play_bgm(key: String, volume_db: float = 0.0) -> void:
	if not _audio_table.has(key):
		push_warning("BGM key not registered: %s" % key)
		return
	_bgm_player.stream = _audio_table[key]
	_bgm_player.volume_db = volume_db
	_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()

# ---- SFX ----

func play_sfx(key: String, volume_db: float = 0.0) -> void:
	if not _audio_table.has(key):
		push_warning("SFX key not registered: %s" % key)
		return
	for ch in _sfx_players:
		if not ch.playing:
			ch.stream = _audio_table[key]
			ch.volume_db = volume_db
			ch.play()
			return
	push_warning("All SFX channels busy — dropping '%s'" % key)

func stop_all_sfx() -> void:
	for ch in _sfx_players:
		ch.stop()

# ---- Volume (0–100 linear mapped to dB) ----

func set_bus_volume(bus_name: StringName, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var db := linear_to_db(clampf(percent / 100.0, 0.0, 1.0))
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, percent <= 0.0)

func get_bus_volume(bus_name: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 100.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx)) * 100.0

# ---- Persist ----

func load_volume_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	set_bus_volume(&"Master", cfg.get_value("audio", "master_volume", 100.0))
	set_bus_volume(&"Music",  cfg.get_value("audio", "bgm_volume", 100.0))
	set_bus_volume(&"SFX",    cfg.get_value("audio", "sfx_volume", 100.0))
