class_name VNEngineSettings
extends RefCounted

signal changed

const TEXT_SPEED_MIN := 0.005
const TEXT_SPEED_MAX := 0.10

const AUTO_SPEED_MIN := 0.5
const AUTO_SPEED_MAX := 5.0

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const REQUIRED_BUSES: Array[String] = ["Music", "Sfx", "Voice"]

var fullscreen: bool = false
var window_size: Vector2i = Vector2i.ZERO
var vsync: bool = true
var display_customized: bool = false

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var voice_volume: float = 1.0
var speaker_voice_volume: Dictionary = {}
var mute_on_focus_loss: bool = false

var text_speed: float = 0.05
var auto_speed: float = 2.0
var skip_unread: bool = false
var window_opacity: float = 0.85

var autosave: bool = true

var input_overrides: Dictionary = {}

var _path: String = ""

static var _focus_muted: bool = false

static var _master_audio_saved: bool = false
static var _master_volume_db_original: float = 0.0
static var _master_muted_original: bool = false


static func load_from(path: String) -> VNEngineSettings:
	var settings: VNEngineSettings = VNEngineSettings.new()
	settings._path = path
	settings._load_from_disk()
	return settings


static func make_draft() -> VNEngineSettings:
	var draft: VNEngineSettings = VNEngineSettings.new()
	var base: VNEngineSettings = VNEngineMain.settings()
	if base != null:
		draft.copy_from(base)
	return draft


static func commit(draft: VNEngineSettings) -> void:
	var current: VNEngineSettings = VNEngineMain.settings()
	if current == null:
		return
	current.copy_from(draft)
	current.apply_all()
	current.save_to_disk()
	current.changed.emit()


static func set_focus_muted(muted: bool) -> void:
	var settings: VNEngineSettings = VNEngineMain.settings()
	if settings == null:
		return
	if muted and not settings.mute_on_focus_loss:
		return
	if _focus_muted == muted:
		return
	_focus_muted = muted
	settings.apply_audio()


func copy_from(other: VNEngineSettings) -> void:
	fullscreen = other.fullscreen
	window_size = other.window_size
	vsync = other.vsync
	display_customized = other.display_customized
	master_volume = other.master_volume
	music_volume = other.music_volume
	sfx_volume = other.sfx_volume
	voice_volume = other.voice_volume
	speaker_voice_volume = other.speaker_voice_volume.duplicate()
	mute_on_focus_loss = other.mute_on_focus_loss
	text_speed = other.text_speed
	auto_speed = other.auto_speed
	skip_unread = other.skip_unread
	window_opacity = other.window_opacity
	autosave = other.autosave
	input_overrides = other.input_overrides.duplicate()


func apply_all() -> void:
	_ensure_audio_buses()
	apply_display()
	apply_audio()
	apply_input()


func apply_audio() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if not _master_audio_saved:
		_master_volume_db_original = AudioServer.get_bus_volume_db(master_bus)
		_master_muted_original = AudioServer.is_bus_mute(master_bus)
		_master_audio_saved = true
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	AudioServer.set_bus_mute(master_bus, _focus_muted)

	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))

	var sfx_idx: int = AudioServer.get_bus_index("Sfx")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))

	var voice_idx: int = AudioServer.get_bus_index("Voice")
	if voice_idx != -1:
		AudioServer.set_bus_volume_db(voice_idx, linear_to_db(voice_volume))


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window: Window = (Engine.get_main_loop() as SceneTree).root
	if display_customized:
		if fullscreen:
			window.mode = Window.MODE_FULLSCREEN
		else:
			var target: Vector2i = effective_window_size()
			var was_windowed: bool = window.mode == Window.MODE_WINDOWED
			window.mode = Window.MODE_WINDOWED
			if not was_windowed or window.size != target:
				window.size = target
				_center_window(window, target)

		var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(vsync_mode)

	_fit_to_screen(window)


func _fit_to_screen(window: Window) -> void:
	if window.mode != Window.MODE_WINDOWED:
		return
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	if window.size.x <= usable.size.x and window.size.y <= usable.size.y:
		return
	var target: Vector2i = Vector2i.ZERO
	for size: Vector2i in WINDOW_SIZES:
		if size.x <= usable.size.x and size.y <= usable.size.y and size.x * size.y > target.x * target.y:
			target = size
	if target == Vector2i.ZERO:
		var scale: float = minf(float(usable.size.x) / window.size.x, float(usable.size.y) / window.size.y)
		target = Vector2i(int(window.size.x * scale), int(window.size.y * scale))
	window.size = target
	_center_window(window, target, usable)


func _center_window(window: Window, size: Vector2i, usable_rect: Variant = null) -> void:
	var screen_rect: Rect2i = usable_rect if usable_rect is Rect2i else DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position = screen_rect.position + (screen_rect.size - size) / 2


func apply_input() -> void:
	var overrides: Variant = input_overrides
	if not overrides is Dictionary:
		overrides = {}
	VNEngineInput.apply_overrides(overrides)


func effective_window_size() -> Vector2i:
	if window_size != Vector2i.ZERO:
		return window_size
	var window: Window = (Engine.get_main_loop() as SceneTree).root
	return window.size


var text_speed_normalized: float:
	get:
		var speed: float = clampf(text_speed, TEXT_SPEED_MIN, TEXT_SPEED_MAX)
		return inverse_lerp(TEXT_SPEED_MAX, TEXT_SPEED_MIN, speed)
	set(t):
		t = clampf(t, 0.0, 1.0)
		text_speed = lerpf(TEXT_SPEED_MAX, TEXT_SPEED_MIN, t)


var auto_speed_normalized: float:
	get:
		var speed: float = clampf(auto_speed, AUTO_SPEED_MIN, AUTO_SPEED_MAX)
		return inverse_lerp(AUTO_SPEED_MAX, AUTO_SPEED_MIN, speed)
	set(t):
		t = clampf(t, 0.0, 1.0)
		auto_speed = lerpf(AUTO_SPEED_MAX, AUTO_SPEED_MIN, t)


func save_to_disk() -> void:
	if _path == "":
		return
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_to_dict(), "\t"))
		file.close()


func restore_audio() -> void:
	if not _master_audio_saved:
		return
	var master_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, _master_volume_db_original)
	AudioServer.set_bus_mute(master_bus, _master_muted_original)


func _ensure_audio_buses() -> void:
	for bus_name: String in REQUIRED_BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _to_dict() -> Dictionary:
	return {
		"fullscreen": fullscreen,
		"window_size": "%dx%d" % [window_size.x, window_size.y] if window_size != Vector2i.ZERO else "",
		"vsync": vsync,
		"display_customized": display_customized,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"voice_volume": voice_volume,
		"speaker_voice_volume": speaker_voice_volume,
		"mute_on_focus_loss": mute_on_focus_loss,
		"text_speed": text_speed,
		"auto_speed": auto_speed,
		"skip_unread": skip_unread,
		"window_opacity": window_opacity,
		"autosave": autosave,
		"input_overrides": input_overrides,
	}


func _load_from_disk() -> void:
	if not FileAccess.file_exists(_path):
		return

	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	var json_str: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(json_str) != OK:
		VNEngineLog.warn("VNEngineSettings", "settings.json could not be parsed, using defaults")
		return

	var loaded_data: Variant = json.get_data()
	if not loaded_data is Dictionary:
		VNEngineLog.warn("VNEngineSettings", "settings.json has an unexpected shape, using defaults")
		return

	var loaded: Dictionary = loaded_data
	if loaded.has("fullscreen"):
		fullscreen = bool(loaded["fullscreen"])
	if loaded.has("window_size"):
		window_size = _parse_size(String(loaded["window_size"]))
	if loaded.has("vsync"):
		vsync = bool(loaded["vsync"])
	if loaded.has("display_customized"):
		display_customized = bool(loaded["display_customized"])
	if loaded.has("master_volume"):
		master_volume = float(loaded["master_volume"])
	if loaded.has("music_volume"):
		music_volume = float(loaded["music_volume"])
	if loaded.has("sfx_volume"):
		sfx_volume = float(loaded["sfx_volume"])
	if loaded.has("voice_volume"):
		voice_volume = float(loaded["voice_volume"])
	if loaded.has("speaker_voice_volume") and loaded["speaker_voice_volume"] is Dictionary:
		speaker_voice_volume = loaded["speaker_voice_volume"]
	if loaded.has("mute_on_focus_loss"):
		mute_on_focus_loss = bool(loaded["mute_on_focus_loss"])
	if loaded.has("text_speed"):
		text_speed = float(loaded["text_speed"])
	if loaded.has("auto_speed"):
		auto_speed = float(loaded["auto_speed"])
	if loaded.has("skip_unread"):
		skip_unread = bool(loaded["skip_unread"])
	if loaded.has("window_opacity"):
		window_opacity = float(loaded["window_opacity"])
	if loaded.has("autosave"):
		autosave = bool(loaded["autosave"])
	if loaded.has("input_overrides") and loaded["input_overrides"] is Dictionary:
		input_overrides = loaded["input_overrides"]


func _parse_size(text: String) -> Vector2i:
	var parts: PackedStringArray = text.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(parts[0].to_int(), parts[1].to_int())
