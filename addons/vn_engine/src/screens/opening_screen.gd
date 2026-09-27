class_name VNEngineOpeningScreen
extends VNEngineScreen


var _finished_called: bool = false
var _tween: Tween = null

var _queue: Array[VNEngineBootScreenDef] = []
var _step_index: int = -1
var _current_step_token: int = 0
var _current_skippable: bool = true
var _waiting_for_input: bool = false

@onready var video_player: VideoStreamPlayer = %OpeningVideoPlayer
@onready var boot_background: ColorRect = %BootBackground
@onready var boot_image: TextureRect = %BootImage


func _ready() -> void:
	video_player.finished.connect(_on_video_finished)


func _unhandled_input(event: InputEvent) -> void:
	if _finished_called:
		return
	if not (_waiting_for_input or _current_skippable):
		return

	var is_advance: bool = event.is_action_pressed(VNEngineInput.ADVANCE)
	var is_left_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if not (is_advance or is_left_click):
		return

	get_viewport().set_input_as_handled()
	_skip_current_step()


func screen_id() -> StringName:
	return &"opening"


func enter(_params: Dictionary) -> void:
	_reset_step_visuals()
	_queue = _build_queue()
	if _queue.is_empty():
		_abort()
		return

	_step_index = -1
	_current_step_token = 0
	_start_next_step()


func _build_queue() -> Array[VNEngineBootScreenDef]:
	var queue: Array[VNEngineBootScreenDef] = []
	if VNEngineMain.game().manifest == null:
		return queue

	var boot: VNEngineBootDef = VNEngineMain.game().manifest.get_boot()
	for screen: VNEngineBootScreenDef in boot.boot_screens:
		if screen != null and screen.enabled:
			queue.append(screen)

	return queue


func _start_next_step() -> void:
	_step_index += 1
	if _step_index >= _queue.size():
		_finish()
		return

	_current_step_token += 1
	var token: int = _current_step_token
	_reset_step_visuals()

	_start_screen(_queue[_step_index], token)


func _advance_if_current(token: int) -> void:
	if _finished_called or token != _current_step_token:
		return
	_start_next_step()


func _skip_current_step() -> void:
	if video_player.is_playing():
		video_player.stop()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

	_advance_if_current(_current_step_token)


func _reset_step_visuals() -> void:
	boot_background.visible = false
	boot_image.visible = false
	video_player.visible = false
	if video_player.is_playing():
		video_player.stop()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_current_skippable = true
	_waiting_for_input = false


func _on_video_finished() -> void:
	_advance_if_current(_current_step_token)


func _start_screen(screen: VNEngineBootScreenDef, token: int) -> void:
	_current_skippable = screen.skippable
	boot_background.color = screen.background_color
	boot_background.visible = true

	if screen.movie_path != "":
		var stream: VideoStream = load(screen.movie_path) as VideoStream
		if stream != null:
			var root: VNEngineMain = VNEngineMain.instance()
			if root != null:
				root.persistent_audio.stop_bgm()
			video_player.stream = stream
			video_player.visible = true
			video_player.play()
			return
		VNEngineLog.warn("OpeningScreen", "movie_path is not a VideoStream, trying image_path: '%s'" % screen.movie_path)

	if screen.image_path != "":
		var texture: Texture2D = load(screen.image_path) as Texture2D
		if texture != null:
			_play_screen_image(texture, screen, token)
			return
		VNEngineLog.warn("OpeningScreen", "image_path is not a Texture2D: '%s'" % screen.image_path)

	VNEngineLog.warn("OpeningScreen", "Boot step has no usable movie or image, skipping")
	call_deferred("_advance_if_current", token)


func _play_screen_image(texture: Texture2D, screen: VNEngineBootScreenDef, token: int) -> void:
	boot_image.texture = texture
	boot_image.modulate.a = 0.0
	boot_image.visible = true

	var fade: float = maxf(screen.fade_time, 0.0)

	if screen.wait_for_input:
		_current_skippable = false
		_waiting_for_input = true
		_tween = create_tween()
		_tween.tween_property(boot_image, "modulate:a", 1.0, fade)
		return

	var total: float = maxf(screen.duration, fade * 2.0 + 0.1)
	var hold: float = total - fade * 2.0

	_tween = create_tween()
	_tween.tween_property(boot_image, "modulate:a", 1.0, fade)
	_tween.tween_interval(hold)
	_tween.tween_property(boot_image, "modulate:a", 0.0, fade)
	_tween.tween_callback(_advance_if_current.bind(token))


func _abort() -> void:
	call_deferred("_finish")


func _finish() -> void:
	if _finished_called:
		return
	_finished_called = true
	if video_player.is_playing():
		video_player.stop()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	VNEngineMain.game().return_to_title()
