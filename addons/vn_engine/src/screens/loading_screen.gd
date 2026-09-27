class_name VNEngineLoadingScreen
extends VNEngineScreen


const TIMEOUT_SECONDS: float = 10.0
const FADE_DURATION: float = 0.3

var _all_paths: PackedStringArray = PackedStringArray()
var _pending: PackedStringArray = PackedStringArray()
var _preloader: VNEngineChapterPreloader = null
var _next_screen: StringName = &""
var _next_params: Dictionary = {}
var _elapsed: float = 0.0
var _first_frame_checked: bool = false
var _completion_scheduled: bool = false

var _mode: String = "when_slow"
var _min_duration: float = 0.0
var _loading_finished: bool = false

@onready var _progress_bar: ProgressBar = get_node_or_null("%LoadingBar") as ProgressBar
@onready var _label: Label = get_node_or_null("%LoadingLabel") as Label
@onready var _status_label: Label = get_node_or_null("%LoadingStatusLabel") as Label
@onready var _title_label: Label = get_node_or_null("%LoadingTitleLabel") as Label
@onready var _subtitle_label: Label = get_node_or_null("%LoadingSubtitleLabel") as Label
@onready var _background_rect: TextureRect = get_node_or_null("%LoadingBackgroundRect") as TextureRect


func _process(delta: float) -> void:
	if _completion_scheduled:
		return
	if _mode == "always":
		_process_always(delta)
	else:
		_process_when_slow(delta)


func _poll_pending() -> float:
	var progress_sum: float = 0.0
	var still_pending: PackedStringArray = PackedStringArray()

	for path in _pending:
		var progress_arr: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(path, progress_arr)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				ResourceLoader.load_threaded_get(path)
				progress_sum += 1.0
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var progress: float = 0.0
				if not progress_arr.is_empty():
					progress = float(progress_arr[0])
				progress_sum += progress
				still_pending.append(path)
			_:
				VNEngineLog.warn("LoadingScreen", "Failed to load '%s'" % path)
				progress_sum += 1.0

	_pending = still_pending
	return progress_sum


func _still_loading() -> bool:
	return not _pending.is_empty() or (_preloader != null and not _preloader.is_done())


func _poll_all() -> float:
	var stage_progress_sum: float = _poll_pending()
	var stage_count: int = _all_paths.size()

	var preload_count: int = 0
	var preload_progress_sum: float = 0.0
	if _preloader != null:
		preload_count = _preloader.asset_count()
		preload_progress_sum = _preloader.poll() * float(preload_count)

	var total: int = stage_count + preload_count
	if total == 0:
		return 1.0
	return (stage_progress_sum + preload_progress_sum) / float(total)


func _update_status_label() -> void:
	if _preloader != null and _preloader.asset_count() > 0 and not _preloader.is_done():
		_status_label.text = "Loading assets %d/%d" % [_preloader.loaded_count(), _preloader.asset_count()]
	else:
		_status_label.text = ""


func _process_when_slow(delta: float) -> void:
	if not _still_loading():
		return

	_elapsed += delta
	var ratio: float = _poll_all()

	if not _first_frame_checked:
		_first_frame_checked = true
		if not _still_loading():
			_schedule_completion()
			return
		_progress_bar.visible = true
		_label.visible = true
		_status_label.visible = true

	_progress_bar.value = ratio
	_update_status_label()

	if not _still_loading():
		_schedule_completion()
		return

	if _elapsed >= TIMEOUT_SECONDS:
		VNEngineLog.warn("LoadingScreen", "Timed out (%.1fs), abandoning remaining preload work" % TIMEOUT_SECONDS)
		_schedule_completion()


func _process_always(delta: float) -> void:
	_elapsed += delta

	var ratio: float = 1.0
	if not _loading_finished:
		ratio = _poll_all()
		_update_status_label()
		if not _still_loading():
			_loading_finished = true
		elif _elapsed >= TIMEOUT_SECONDS:
			VNEngineLog.warn("LoadingScreen", "Timed out (%.1fs), abandoning remaining preload work" % TIMEOUT_SECONDS)
			_loading_finished = true
			ratio = 1.0

	_progress_bar.value = ratio

	if _loading_finished and _elapsed >= _min_duration:
		_schedule_completion()


func screen_id() -> StringName:
	return &"loading"


func enter(params: Dictionary) -> void:
	_completion_scheduled = false
	_elapsed = 0.0
	_first_frame_checked = false
	_loading_finished = false
	_next_screen = params.get("next_screen", &"")
	_next_params = params.get("next_params", {})
	_all_paths = PackedStringArray()
	_pending = PackedStringArray()
	_preloader = params.get("preloader", null) as VNEngineChapterPreloader
	_mode = String(params.get("mode", "when_slow"))
	_min_duration = float(params.get("min_duration", 0.0))

	_progress_bar.visible = (_mode == "always")
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0

	_label.visible = (_mode == "always")

	_status_label.visible = (_mode == "always")
	_status_label.text = ""

	if _mode == "always":
		_apply_chapter_info(params)
	else:
		_hide_chapter_info()

	var requested_paths: PackedStringArray = params.get("paths", PackedStringArray())
	for path in requested_paths:
		if not ResourceLoader.exists(path):
			VNEngineLog.warn("LoadingScreen", "Preload path not found: '%s'" % path)
			continue
		var err: Error = ResourceLoader.load_threaded_request(path)
		if err != OK:
			VNEngineLog.warn("LoadingScreen", "Failed to start loading '%s'" % path)
			continue
		_all_paths.append(path)
		_pending.append(path)

	if _mode == "always":
		modulate = Color(1, 1, 1, 0)
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
		if not _still_loading():
			_loading_finished = true
	else:
		modulate = Color(1, 1, 1, 1)
		if not _still_loading():
			_schedule_completion()


func _apply_chapter_info(params: Dictionary) -> void:
	var title: String = String(params.get("title", ""))
	var subtitle: String = String(params.get("subtitle", ""))
	var background_path: String = String(params.get("background_path", ""))

	_title_label.text = title
	_title_label.visible = title != ""
	_subtitle_label.text = subtitle
	_subtitle_label.visible = subtitle != ""

	if background_path != "" and ResourceLoader.exists(background_path):
		_background_rect.texture = load(background_path)
		_background_rect.visible = true
	else:
		_background_rect.texture = null
		_background_rect.visible = false


func _hide_chapter_info() -> void:
	_title_label.visible = false
	_subtitle_label.visible = false
	_background_rect.visible = false


func handle_back() -> bool:
	return true


func _schedule_completion() -> void:
	if _completion_scheduled:
		return
	_completion_scheduled = true

	if _mode == "always":
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
		tween.finished.connect(_complete)
	else:
		call_deferred("_complete")


func _complete() -> void:
	VNEngineMain.instance().screen_stack.replace_screen(_next_screen, _next_params)
