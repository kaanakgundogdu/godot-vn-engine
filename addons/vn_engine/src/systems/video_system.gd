class_name VNEngineVideoSystem
extends VideoStreamPlayer

const TEXTURE_WAIT_FRAMES: int = 10

@export var runner: VNEngineStoryRunner
@export var dialog_ui: VNEngineDialogUI

var _letterbox: ColorRect = null

var _fade_tween: Tween = null


func _ready() -> void:
	hide()
	expand = true

	if AudioServer.get_bus_index("Music") != -1:
		bus = "Music"
	else:
		VNEngineLog.warn("VideoSystem", "'Music' audio bus not found, video audio stays on 'Master'")

	finished.connect(_on_video_finished)

	if runner:
		runner.register_manager(self)


func play_movie(movie_name: String) -> void:
	var path: String = ""
	if runner and runner.ctx and runner.ctx.assets:
		path = runner.ctx.assets.resolve("movie", movie_name)
	else:
		VNEngineLog.warn("VideoSystem", "AssetResolver unavailable (no runner/ctx/assets), skipping video: %s" % movie_name)

	if path == "":
		if runner:
			runner.bus.resolve_block()
		return

	stream = load(path) as VideoStream

	var audio: VNEngineAudioSystem = _get_audio()
	if audio != null:
		audio.pause_for_video()

	_reset_to_fullscreen()
	if _letterbox != null and is_instance_valid(_letterbox):
		_letterbox.hide()

	if dialog_ui and not dialog_ui.is_ui_hidden:
		dialog_ui.toggle_ui()

	modulate.a = 0.0
	play()

	if runner:
		runner.is_input_locked = true

	await _await_video_texture()
	_apply_pillarbox()

	show()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _on_video_finished() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 1.0
	hide()
	if _letterbox != null and is_instance_valid(_letterbox):
		_letterbox.hide()

	if runner:
		runner.is_input_locked = false

	if dialog_ui and dialog_ui.is_ui_hidden:
		dialog_ui.toggle_ui()

	var audio: VNEngineAudioSystem = _get_audio()
	if audio != null:
		audio.resume_after_video()

	if runner:
		runner.bus.resolve_block()


func _input(event: InputEvent) -> void:
	if is_playing() and event.is_action_pressed(VNEngineInput.ADVANCE):
		stop()
		_on_video_finished()


func _get_audio() -> VNEngineAudioSystem:
	if runner and runner.ctx:
		return runner.ctx.audio
	return null


func _await_video_texture() -> void:
	for _i in TEXTURE_WAIT_FRAMES:
		await get_tree().process_frame
		if not is_inside_tree() or not is_playing():
			return
		var tex: Texture2D = get_video_texture()
		if tex != null and tex.get_size().x > 0.0 and tex.get_size().y > 0.0:
			return


func _reset_to_fullscreen() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _apply_pillarbox() -> void:
	var video_texture: Texture2D = get_video_texture()
	if video_texture == null:
		return

	var video_size: Vector2 = video_texture.get_size()
	if video_size.x <= 0.0 or video_size.y <= 0.0:
		return

	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		return

	var parent_size: Vector2 = parent_control.size
	if parent_size.x <= 0.0 or parent_size.y <= 0.0:
		return

	var fit_scale: float = min(parent_size.x / video_size.x, parent_size.y / video_size.y)
	var target_w: float = video_size.x * fit_scale
	var target_h: float = video_size.y * fit_scale

	var letterbox: ColorRect = _ensure_letterbox()
	letterbox.show()

	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -target_w / 2.0
	offset_top = -target_h / 2.0
	offset_right = target_w / 2.0
	offset_bottom = target_h / 2.0


func _ensure_letterbox() -> ColorRect:
	if _letterbox != null and is_instance_valid(_letterbox):
		return _letterbox

	var rect: ColorRect = ColorRect.new()
	rect.name = "VideoLetterbox"
	rect.color = Color.BLACK
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var parent_node: Node = get_parent()
	parent_node.add_child(rect)
	parent_node.move_child(rect, get_index())

	_letterbox = rect
	return _letterbox
