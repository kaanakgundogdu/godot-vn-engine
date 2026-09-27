class_name VNEngineAudioSystem
extends Node

@export var channels: Array[VNEngineAudioChannel] = []
@export var crossfade_duration: float = 1.0

var runner: VNEngineStoryRunner

var _players: Dictionary = {}
var _tweens: Dictionary = {}
var _current_files: Dictionary = {}
var _video_pause_count: int = 0


func _ready() -> void:
	for channel: VNEngineAudioChannel in channels:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = channel.command_name.capitalize() + "Player"
		player.bus = channel.bus_name
		add_child(player)

		_players[channel.command_name] = {
			"config": channel,
			"node": player,
		}


func attach_runner(new_runner: VNEngineStoryRunner) -> void:
	runner = new_runner
	runner.state_restored.connect(_on_state_restored)
	runner.register_manager(self)


func detach_runner() -> void:
	if runner != null and runner.state_restored.is_connected(_on_state_restored):
		runner.state_restored.disconnect(_on_state_restored)
	runner = null
	_stop_audio("sfx")
	_stop_audio("voice")
	_video_pause_count = 0
	if _players.has("music"):
		(_players["music"]["node"] as AudioStreamPlayer).stream_paused = false


func _on_state_restored(state: VNEngineStoryState) -> void:
	for key: String in _players.keys():
		var target_file: String = state.audio.get(key, "")
		var player: AudioStreamPlayer = _players[key]["node"]
		var same_file: bool = target_file == _current_files.get(key, "")
		if same_file and (player.playing or player.stream_paused):
			continue

		if target_file == "":
			_stop_audio(key)
		else:
			_play_audio(key, target_file)


func play_channel(channel_name: String, file_name: String, speaker_id: String = "") -> void:
	if _players.has(channel_name):
		_play_audio(channel_name, file_name, speaker_id)


func play_bgm(resolved_path: String, restart: bool = false) -> void:
	if resolved_path == "" or not _players.has("music"):
		return
	_play_audio("music", resolved_path, "", resolved_path, restart)


func stop_bgm() -> void:
	if _players.has("music"):
		_stop_audio("music")


func pause_for_video() -> void:
	_video_pause_count += 1
	if _video_pause_count > 1:
		return
	if _players.has("music"):
		var music_player: AudioStreamPlayer = _players["music"]["node"]
		if music_player.playing:
			music_player.stream_paused = true
	_stop_audio("sfx")
	_stop_audio("voice")


func resume_after_video() -> void:
	if _video_pause_count <= 0:
		return
	_video_pause_count -= 1
	if _video_pause_count > 0:
		return
	if _players.has("music"):
		var music_player: AudioStreamPlayer = _players["music"]["node"]
		music_player.stream_paused = false


func _play_audio(channel_name: String, file_name: String, speaker_id: String = "", resolved_path: String = "", force_restart: bool = false) -> void:
	var data: Dictionary = _players[channel_name]
	var config: VNEngineAudioChannel = data["config"]
	var player: AudioStreamPlayer = data["node"]

	if file_name.to_lower() == "stop":
		_stop_audio(channel_name)
		return

	if not force_restart and file_name == _current_files.get(channel_name, ""):
		if player.playing or player.stream_paused:
			return

	var file_path: String = resolved_path
	if file_path == "":
		file_path = runner.ctx.assets.resolve(channel_name, file_name)

	if file_path == "":
		return

	var new_stream: AudioStream = load(file_path) as AudioStream
	if channel_name == "music" and new_stream != null:
		_apply_music_loop(new_stream)
	_current_files[channel_name] = file_name

	var base_db: float = config.base_volume_db

	if channel_name == "voice" and speaker_id != "":
		var voice_mult: float = VNEngineMain.settings().speaker_voice_volume.get(speaker_id, 1.0)
		base_db += maxf(linear_to_db(voice_mult), -80.0)

	if config.use_fade:
		if _tweens.has(channel_name) and _tweens[channel_name].is_valid():
			_tweens[channel_name].kill()

		var tween: Tween = create_tween()
		_tweens[channel_name] = tween

		if player.playing:
			tween.tween_property(player, "volume_db", base_db - 40.0, crossfade_duration / 2.0)
			tween.tween_callback(func() -> void:
				player.stream = new_stream
				player.play()
			)
			tween.tween_property(player, "volume_db", base_db, crossfade_duration / 2.0)
		else:
			player.stream = new_stream
			player.volume_db = base_db - 40.0
			player.play()
			tween.tween_property(player, "volume_db", base_db, crossfade_duration)
	else:
		player.stream = new_stream
		player.volume_db = base_db
		player.play()


func _apply_music_loop(stream: AudioStream) -> void:
	if "loop" in stream:
		stream.loop = true
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


func _stop_audio(channel_name: String) -> void:
	var data: Dictionary = _players[channel_name]
	var config: VNEngineAudioChannel = data["config"]
	var player: AudioStreamPlayer = data["node"]

	_current_files[channel_name] = ""

	var base_db: float = config.base_volume_db

	if config.use_fade:
		if _tweens.has(channel_name) and _tweens[channel_name].is_valid():
			_tweens[channel_name].kill()

		var tween: Tween = create_tween()
		_tweens[channel_name] = tween
		tween.tween_property(player, "volume_db", base_db - 80.0, crossfade_duration)
		tween.tween_callback(player.stop)
	else:
		player.stop()
