class_name VNEngineCardOverlay
extends Control

signal finished
signal covered

const MODE_TITLE: String = "title"
const MODE_IMAGE: String = "image"
const MODE_DATECARD: String = "datecard"
const MODE_MOVIE: String = "movie"

const TEXTURE_WAIT_FRAMES: int = 10

var _current_mode: String = ""
var _current_movie_id: String = ""

var _hold_on_close: bool = false
var _held: bool = false

var _tween: Tween
var _close_timer: Timer
var _fade_duration: float = 0.4
var _saved_focus: Control = null
var _audio_paused: bool = false

@onready var _background: ColorRect = %CardBackground
@onready var _image_rect: TextureRect = %CardImageRect
@onready var _video_player: VideoStreamPlayer = %CardVideoPlayer
@onready var _title_container: CenterContainer = %TitleContainer
@onready var _title_label: Label = %CardTitleLabel
@onready var _subtitle_label: Label = %CardSubtitleLabel
@onready var _datecard_container: CenterContainer = %DateCardContainer
@onready var _line1_label: Label = %CardLine1Label
@onready var _line2_label: Label = %CardLine2Label
@onready var _line3_label: Label = %CardLine3Label


func _ready() -> void:
	hide()
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_close_timer = Timer.new()
	_close_timer.one_shot = true
	_close_timer.timeout.connect(_start_close)
	add_child(_close_timer)

	_video_player.finished.connect(_on_video_player_finished)


func open(mode: String, params: Dictionary, duration: float = 2.0, fade_duration: float = 0.4) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_close_timer.stop()

	_current_mode = mode
	_current_movie_id = ""
	_hold_on_close = bool(params.get("hold_on_close", false))
	_held = false

	match mode:
		MODE_TITLE:
			if not _apply_title(params):
				_fail_and_finish()
				return
		MODE_IMAGE:
			if not _apply_image(params):
				_fail_and_finish()
				return
		MODE_DATECARD:
			_apply_datecard(params)
		MODE_MOVIE:
			var audio: VNEngineAudioSystem = _get_audio()
			if audio != null and not _audio_paused:
				audio.pause_for_video()
				_audio_paused = true
			if not _apply_movie(params):
				_fail_and_finish()
				return
		_:
			VNEngineLog.warn("CardOverlay", "Unknown mode: '%s'" % mode)
			_fail_and_finish()
			return

	_fade_duration = fade_duration
	show()
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_take_focus()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	_tween.tween_callback(covered.emit)

	if mode == MODE_MOVIE:
		_video_player.play()
		await _await_video_texture()
		_apply_video_pillarbox()
	elif duration > 0.0:
		_close_timer.start(duration)


func _input(event: InputEvent) -> void:
	if not _is_blocking():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		return
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.pressed and (mouse.button_index == MOUSE_BUTTON_LEFT or mouse.button_index == MOUSE_BUTTON_RIGHT):
			_start_close()
	elif event.is_action_pressed(VNEngineInput.ADVANCE):
		_start_close()


func _is_blocking() -> bool:
	return visible and not _held and mouse_filter == Control.MOUSE_FILTER_STOP


func _take_focus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	if _saved_focus == null:
		_saved_focus = focused
	focused.release_focus()


func _restore_focus() -> void:
	if is_instance_valid(_saved_focus) and _saved_focus.is_visible_in_tree():
		_saved_focus.grab_focus()
	_saved_focus = null


func _on_video_player_finished() -> void:
	if not visible or _held:
		return
	_start_close()


func _apply_title(params: Dictionary) -> bool:
	_show_only(_title_container)
	var title_text: String = params.get("title", "")
	var subtitle_text: String = params.get("subtitle", "")
	_title_label.text = title_text
	_subtitle_label.text = subtitle_text
	_title_label.visible = title_text != ""
	_subtitle_label.visible = subtitle_text != ""
	return true


func _apply_image(params: Dictionary) -> bool:
	var image_path: String = params.get("image_path", "")
	if image_path == "" or not ResourceLoader.exists(image_path):
		VNEngineLog.warn("CardOverlay", "Invalid image_path: '%s'" % image_path)
		return false

	var texture: Texture2D = load(image_path) as Texture2D
	_image_rect.texture = texture
	_show_only(_image_rect)
	_background.visible = true
	return true


func _apply_movie(params: Dictionary) -> bool:
	var movie_path: String = params.get("movie_path", "")
	if movie_path == "" or not ResourceLoader.exists(movie_path):
		VNEngineLog.warn("CardOverlay", "Invalid movie_path: '%s'" % movie_path)
		return false

	_current_movie_id = params.get("movie_id", "")

	var stream: VideoStream = load(movie_path) as VideoStream
	if stream == null:
		VNEngineLog.warn("CardOverlay", "movie_path did not resolve to a VideoStream: '%s'" % movie_path)
		return false

	_reset_video_player_to_fullscreen()

	_video_player.stream = stream
	_show_only(_video_player)
	_background.visible = true
	return true


func _await_video_texture() -> void:
	for _i in TEXTURE_WAIT_FRAMES:
		await get_tree().process_frame
		if not is_inside_tree() or not _video_player.is_playing():
			return
		var tex: Texture2D = _video_player.get_video_texture()
		if tex != null and tex.get_size().x > 0.0 and tex.get_size().y > 0.0:
			return


func _reset_video_player_to_fullscreen() -> void:
	_video_player.anchor_left = 0.0
	_video_player.anchor_top = 0.0
	_video_player.anchor_right = 1.0
	_video_player.anchor_bottom = 1.0
	_video_player.offset_left = 0.0
	_video_player.offset_top = 0.0
	_video_player.offset_right = 0.0
	_video_player.offset_bottom = 0.0


func _apply_video_pillarbox() -> void:
	var video_texture: Texture2D = _video_player.get_video_texture()
	if video_texture == null:
		return

	var video_size: Vector2 = video_texture.get_size()
	if video_size.x <= 0.0 or video_size.y <= 0.0:
		return

	var parent_size: Vector2 = size
	if parent_size.x <= 0.0 or parent_size.y <= 0.0:
		return

	var fit_scale: float = min(parent_size.x / video_size.x, parent_size.y / video_size.y)
	var target_w: float = video_size.x * fit_scale
	var target_h: float = video_size.y * fit_scale

	_video_player.anchor_left = 0.5
	_video_player.anchor_top = 0.5
	_video_player.anchor_right = 0.5
	_video_player.anchor_bottom = 0.5
	_video_player.offset_left = -target_w / 2.0
	_video_player.offset_top = -target_h / 2.0
	_video_player.offset_right = target_w / 2.0
	_video_player.offset_bottom = target_h / 2.0


func _apply_datecard(params: Dictionary) -> void:
	_show_only(_datecard_container)
	var line1: String = params.get("line1", "")
	var line2: String = params.get("line2", "")
	var line3: String = params.get("line3", "")
	_line1_label.text = line1
	_line1_label.visible = line1 != ""
	_line2_label.text = line2
	_line2_label.visible = line2 != ""
	_line3_label.text = line3
	_line3_label.visible = line3 != ""


func _release_audio() -> void:
	if not _audio_paused:
		return
	_audio_paused = false
	var audio: VNEngineAudioSystem = _get_audio()
	if audio != null:
		audio.resume_after_video()


func _get_audio() -> VNEngineAudioSystem:
	var root: VNEngineMain = VNEngineMain.instance()
	if root == null:
		return null
	return root.persistent_audio


func _show_only(node_to_show: Control) -> void:
	_background.visible = true
	_image_rect.visible = node_to_show == _image_rect
	_video_player.visible = node_to_show == _video_player
	_title_container.visible = node_to_show == _title_container
	_datecard_container.visible = node_to_show == _datecard_container


func _fail_and_finish() -> void:
	_release_audio()
	finished.emit.call_deferred()


func _start_close() -> void:
	if not visible or _held:
		return

	if _current_mode == MODE_MOVIE and _current_movie_id != "":
		VNEngineMain.save_data().unlock_movie(_current_movie_id)

	_close_timer.stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_focus()

	if _video_player.is_playing():
		_video_player.stop()

	if _tween and _tween.is_valid():
		_tween.kill()

	if _hold_on_close:
		_held = true
		modulate.a = 1.0
		_show_only(null)
		_release_audio()
		finished.emit()
		return

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, _fade_duration)
	_tween.finished.connect(_on_close_finished)


func release(fade_duration: float = -1.0) -> void:
	if not _held:
		return
	_held = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_duration if fade_duration >= 0.0 else _fade_duration)
	_tween.tween_callback(hide)


func _on_close_finished() -> void:
	hide()
	_release_audio()
	finished.emit()
