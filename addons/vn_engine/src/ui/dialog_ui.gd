class_name VNEngineDialogUI
extends Control

signal line_revealed

const NAME_COLOR_FALLBACK: Color = Color.WHITE
const BOX_FADE_TIME: float = 0.2
const BOX_SLIDE_DISTANCE: float = 12.0
const NAME_FADE_TIME: float = 0.12
const MODE_FADE_TIME: float = 0.25

@export var runner: VNEngineStoryRunner
@export var dialog_label: RichTextLabel
@export var speaker_label: Label
@export var in_game_buttons: VNEngineInGameButtons
@export var choice_ui_root: Control

var is_ui_hidden: bool = false

var _text_tween: Tween
var _indicator_tween: Tween
var _box_tween: Tween
var _name_tween: Tween
var _mode_tween: Tween
var _box_fading_out: bool = false
var _box_rest_position: Vector2 = Vector2.ZERO
var _last_speaker_text: String = ""

var _skip_via_hold: bool = false

var _line_serial: int = 0
var _events: Array = []
var _event_index: int = 0
var _speed_mult: float = 1.0
var _no_wait: bool = false
var _total_chars: int = 0
var _typing: bool = false
var _at_click: bool = false
var _voice_waiting: bool = false
var _voice_wait_id: int = 0
var _voice_wait_serial: int = 0

var _name_plate_style: StyleBoxFlat

var _active_label: RichTextLabel
var _nvl_on: bool = false

@onready var auto_timer: Timer = $AutoTimer
@onready var background_box: Panel = $BackgroundBox
@onready var name_row: HBoxContainer = $NameRow
@onready var name_plate: PanelContainer = $NameRow/NamePlate
@onready var continue_indicator: Label = $ContinueIndicator
@onready var nvl_page: VNEngineNvlPage = $NvlPage


func _ready() -> void:
	hide()
	_active_label = dialog_label
	nvl_page.dialog = self

	if runner:
		runner.register_manager(self)
		runner.dialog_started.connect(_on_dialog_started)
		runner.story_ended.connect(_on_story_ended)
		runner.mode_changed.connect(_on_mode_changed)
		runner.state_restored.connect(_on_state_restored)
		runner.text_mode_changed.connect(_on_text_mode_changed)
		runner.nvl_page_cleared.connect(_on_nvl_page_cleared)

	if auto_timer and not auto_timer.timeout.is_connected(_on_auto_timer_timeout):
		auto_timer.timeout.connect(_on_auto_timer_timeout)

	if auto_timer:
		auto_timer.wait_time = VNEngineMain.settings().auto_speed

	if name_plate:
		var base_style: StyleBox = name_plate.get_theme_stylebox("panel")
		if base_style is StyleBoxFlat:
			_name_plate_style = base_style.duplicate()
			name_plate.add_theme_stylebox_override("panel", _name_plate_style)

	if name_row:
		name_row.alignment = BoxContainer.ALIGNMENT_CENTER if _dialog_name_align() == "center" else BoxContainer.ALIGNMENT_BEGIN

	if background_box:
		var box_style: StyleBox = background_box.get_theme_stylebox("panel")
		if box_style is StyleBoxFlat:
			nvl_page.set_backdrop_color((box_style as StyleBoxFlat).bg_color)

	VNEngineMain.settings().changed.connect(_on_settings_changed)
	_apply_window_opacity()

	var vn_main: VNEngineMain = VNEngineMain.instance()
	var card_overlay: VNEngineCardOverlay = vn_main.get_card_overlay() if vn_main != null else null
	if card_overlay != null:
		card_overlay.covered.connect(clear_text)


func toggle_ui() -> void:
	is_ui_hidden = !is_ui_hidden

	_set_box_visible(!is_ui_hidden)

	if in_game_buttons:
		in_game_buttons.visible = !is_ui_hidden

	if choice_ui_root:
		if is_ui_hidden:
			choice_ui_root.hide()
		elif choice_ui_root.button_container.get_child_count() > 0:
			choice_ui_root.show()


func _on_dialog_started(node: VNEngineStoryNode) -> void:
	if is_ui_hidden:
		toggle_ui()

	if runner.is_nvl() != _nvl_on:
		_switch_mode(runner.is_nvl(), false)

	_set_box_visible(true)
	_hide_continue_indicator()
	_reset_reveal()
	auto_timer.stop()

	if _nvl_on:
		_sync_nvl_page()

	if node.text == "" and not runner.current_choices.is_empty():
		if _nvl_on:
			_on_text_finished()
		else:
			_active_label = dialog_label
			_show_choice_prompt()
		return

	var markup: Dictionary = VNEngineTextMarkup.parse(runner.current_text)
	var text: String = String(markup.get("text", ""))

	if _nvl_on:
		if not nvl_page.fits(node.speaker_id, text, nvl_page.estimate_choices_height(runner.current_choices.size())):
			runner.clear_nvl_page()
		_active_label = nvl_page.add_entry(node.speaker_id, text, "line")
		_apply_seen_color()
		_active_label.visible_characters = 0
	else:
		_active_label = dialog_label
		_apply_speaker(node.speaker_id)
		_apply_seen_color()
		_active_label.visible_characters = 0
		_active_label.text = text

	_events = markup.get("events", [])
	_no_wait = bool(markup.get("no_wait", false))

	_maybe_play_auto_voice(node)

	_total_chars = _active_label.get_parsed_text().length()
	_typing = true
	_build_chain()


func _reset_reveal() -> void:
	_line_serial += 1
	_cancel_voice_wait()
	_kill_text_tween()
	_events = []
	_event_index = 0
	_speed_mult = 1.0
	_no_wait = false
	_total_chars = 0
	_typing = false
	_at_click = false


func _kill_text_tween() -> void:
	if _text_tween != null and _text_tween.is_valid():
		_text_tween.kill()
	_text_tween = null


func _build_chain() -> void:
	_kill_text_tween()
	var text_speed: float = VNEngineMain.settings().text_speed
	var skipping: bool = runner != null and runner.is_skip
	var pos: int = _active_label.visible_characters
	if pos < 0 or pos > _total_chars:
		pos = _total_chars
	var mult: float = _speed_mult

	_text_tween = create_tween()
	for i in range(_event_index, _events.size()):
		var event: Dictionary = _events[i]
		var at: int = clampi(int(event.get("at", 0)), pos, _total_chars)
		if at > pos:
			var step_time: float = (at - pos) * text_speed / mult
			if skipping:
				step_time = step_time / 10.0
			_text_tween.tween_property(_active_label, "visible_characters", at, step_time)
			pos = at
		var value: float = float(event.get("value", 0.0))
		match String(event.get("type", "")):
			"speed":
				mult = value if value > 0.0 else 1.0
				_text_tween.tween_callback(_pass_event.bind(i, mult))
			"wait":
				if not skipping and value > 0.0:
					_text_tween.tween_interval(value)
				_text_tween.tween_callback(_pass_event.bind(i, mult))
			"click":
				if skipping:
					_text_tween.tween_callback(_pass_event.bind(i, mult))
				else:
					_text_tween.tween_callback(_stop_at_click.bind(i))
					return
			_:
				_text_tween.tween_callback(_pass_event.bind(i, mult))

	var duration: float = maxf((_total_chars - pos) * text_speed / mult, 0.01)
	if skipping:
		duration = duration / 10.0
	_text_tween.tween_property(_active_label, "visible_characters", _total_chars, duration)
	_text_tween.tween_callback(_finish_line)


func _pass_event(index: int, mult: float) -> void:
	_event_index = index + 1
	_speed_mult = mult


func _stop_at_click(index: int) -> void:
	_event_index = index + 1
	_at_click = true
	_show_continue_indicator()
	if runner != null and runner.is_auto:
		var serial: int = _line_serial
		get_tree().create_timer(VNEngineMain.settings().auto_speed, false).timeout.connect(func():
			if serial == _line_serial and _at_click and _event_index == index + 1 and runner.is_auto:
				_resume_from_click()
		)


func _resume_from_click() -> void:
	_at_click = false
	_hide_continue_indicator()
	_build_chain()


func _reveal_to_next_stop() -> void:
	_kill_text_tween()
	for i in range(_event_index, _events.size()):
		var event: Dictionary = _events[i]
		var type: String = String(event.get("type", ""))
		if type == "speed":
			var value: float = float(event.get("value", 0.0))
			_speed_mult = value if value > 0.0 else 1.0
		elif type == "click":
			var at: int = clampi(int(event.get("at", 0)), 0, _total_chars)
			_active_label.visible_characters = maxi(_active_label.visible_characters, at)
			_stop_at_click(i)
			return
	_reveal_to_end()


func _reveal_to_end() -> bool:
	_kill_text_tween()
	_event_index = _events.size()
	if _at_click:
		_hide_continue_indicator()
	return _finish_line()


func _finish_line() -> bool:
	_typing = false
	_at_click = false
	_active_label.visible_characters = _total_chars
	if _no_wait and runner.current_choices.is_empty():
		line_revealed.emit()
		runner.next_node()
		return true
	_on_text_finished()
	return false


func _apply_speaker(speaker_id: String) -> void:
	var speaker_text: String = "" if _is_narrator(speaker_id) else _speaker_name(speaker_id)
	if speaker_text == "":
		speaker_label.text = ""
		if name_row:
			name_row.hide()
	else:
		var speaker_changed: bool = speaker_text != _last_speaker_text
		speaker_label.text = speaker_text
		var name_color: Color = speaker_name_color(speaker_id)
		speaker_label.add_theme_color_override("font_color", name_color)
		_apply_name_plate_style(name_color)
		if name_row:
			name_row.show()
		if speaker_changed:
			_fade_in_name_plate()
	_last_speaker_text = speaker_text


func clear_text() -> void:
	_reset_reveal()
	auto_timer.stop()
	_hide_continue_indicator()
	dialog_label.text = ""
	speaker_label.text = ""
	_last_speaker_text = ""
	if name_row:
		name_row.hide()
	if _nvl_on and runner != null:
		runner.clear_nvl_page()


func _show_choice_prompt() -> void:
	_reset_reveal()

	var history: Array[Dictionary] = []
	if runner and runner.state:
		history = runner.state.history
	for i in range(history.size() - 1, -1, -1):
		var entry: Dictionary = history[i]
		var text: String = String(entry.get("text", ""))
		if text == "":
			continue
		_apply_speaker(String(entry.get("speaker", "")))
		_apply_seen_color()
		dialog_label.text = text
		break

	dialog_label.visible_characters = -1
	_on_text_finished()


func _on_story_ended() -> void:
	_set_box_visible(false)
	_hide_continue_indicator()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(VNEngineInput.HIDE_UI):
		toggle_ui()
		return

	if event.is_action_pressed(VNEngineInput.ALT_CLICK):
		if _is_overlay_open():
			return
		if _is_input_locked():
			return
		toggle_ui()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released(VNEngineInput.SKIP_HOLD):
		if _skip_via_hold and runner != null:
			runner.is_skip = false
			runner.mode_changed.emit()
		_skip_via_hold = false
		return

	if _is_overlay_open():
		return

	var input_locked_by_video: bool = runner != null and runner.is_input_locked
	if is_ui_hidden and not input_locked_by_video and (event.is_action_pressed(VNEngineInput.ADVANCE) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)):
		toggle_ui()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(VNEngineInput.ROLLBACK):
		if runner:
			runner.rollback()
		return

	if event.is_action_pressed(VNEngineInput.FORWARD):
		if runner:
			if runner.history_stack.can_forward():
				runner.forward()
			else:
				_advance_dialog()
		return

	if event.is_action_pressed(VNEngineInput.QUICKSAVE):
		if runner:
			VNEngineMain.saves().save_game(runner.state, VNEngineSaveData.QUICKSAVE_SLOT)
		return

	if event.is_action_pressed(VNEngineInput.QUICKLOAD):
		if runner:
			runner.execute_load_game(VNEngineSaveData.QUICKSAVE_SLOT)
		return

	if event.is_action_pressed(VNEngineInput.SKIP_HOLD):
		if not _is_input_locked() and runner != null and not runner.is_skip:
			runner.is_skip = true
			runner.is_auto = false
			runner.mode_changed.emit()
			_skip_via_hold = true
		return

	if event.is_action_pressed(VNEngineInput.AUTO_TOGGLE):
		if not _is_input_locked() and runner != null:
			runner.is_auto = not runner.is_auto
			if runner.is_auto:
				runner.is_skip = false
			runner.mode_changed.emit()
		return

	if event.is_action_pressed(VNEngineInput.OPEN_LOG):
		if not _is_input_locked() and in_game_buttons != null:
			in_game_buttons.log_requested.emit()
		return

	if event.is_action_pressed(VNEngineInput.ADVANCE):
		_advance_dialog()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_advance_dialog()
		accept_event()


func _maybe_play_auto_voice(node: VNEngineStoryNode) -> void:
	var has_manual_voice: bool = false
	for cmd in node.commands:
		if String(cmd.get("name", "")) == "voice" and not cmd.get("after_line", false):
			has_manual_voice = true
			break

	if has_manual_voice:
		return
	if node.line_id == "" or node.speaker_id == "":
		return
	if runner == null or runner.ctx == null:
		return
	if runner.ctx.characters == null or runner.ctx.characters.cast == null:
		return
	if runner.ctx.characters.cast.is_narrator(node.speaker_id):
		return
	if runner.ctx.assets == null or runner.ctx.audio == null:
		return

	var voice_path: String = runner.ctx.assets.resolve_voice(node.speaker_id, node.line_id)
	if voice_path == "":
		return

	var voice_file_name: String = "%s/%s" % [node.speaker_id, node.line_id]
	runner.ctx.audio.play_channel("voice", voice_file_name, node.speaker_id)


func _is_narrator(speaker_id: String) -> bool:
	if speaker_id == "" or runner == null or runner.ctx == null or runner.ctx.characters == null:
		return false
	var db: VNEngineCast = runner.ctx.characters.cast
	return db != null and db.is_narrator(speaker_id)


func _speaker_name(speaker_id: String) -> String:
	if speaker_id == "":
		return ""
	if runner == null or runner.ctx == null or runner.ctx.characters == null:
		return speaker_id.capitalize().to_upper()
	var db: VNEngineCast = runner.ctx.characters.cast
	if db == null:
		return speaker_id.capitalize().to_upper()
	return db.display_name_of(speaker_id)


func speaker_display_name(speaker_id: String) -> String:
	return "" if _is_narrator(speaker_id) else _speaker_name(speaker_id)


func speaker_name_color(speaker_id: String) -> Color:
	if not _dialog_use_character_colors():
		return NAME_COLOR_FALLBACK
	if runner == null or runner.ctx == null or runner.ctx.characters == null:
		return NAME_COLOR_FALLBACK
	var db: VNEngineCast = runner.ctx.characters.cast
	if db == null:
		return NAME_COLOR_FALLBACK
	var entry: VNEngineCastMember = db.get_entry(speaker_id)
	if entry == null:
		return NAME_COLOR_FALLBACK
	return entry.name_color


func _dialog_use_character_colors() -> bool:
	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()
	return ui_def.dialog_use_character_colors


func _animations_enabled() -> bool:
	if runner != null and runner.is_skip:
		return false
	return VNEngineMain.game().get_ui().ui_animations


func _animation_time(base: float) -> float:
	return base * VNEngineMain.game().get_ui().ui_animation_scale


func _set_box_visible(value: bool) -> void:
	if value:
		if visible and not _box_fading_out:
			return
		_reset_box_tween()
		show()
		if not _animations_enabled():
			return
		_box_rest_position = position
		modulate.a = 0.0
		position = _box_rest_position + Vector2(0.0, _box_slide_distance())
		var time: float = _animation_time(BOX_FADE_TIME)
		_box_tween = create_tween().set_parallel(true)
		_box_tween.tween_property(self, "modulate:a", 1.0, time)
		_box_tween.tween_property(self, "position", _box_rest_position, time)
		return

	if not visible or _box_fading_out:
		return
	if not _animations_enabled():
		_reset_box_tween()
		hide()
		return
	_box_rest_position = position
	_box_fading_out = true
	var fade_time: float = _animation_time(BOX_FADE_TIME)
	_box_tween = create_tween().set_parallel(true)
	_box_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	_box_tween.tween_property(self, "position", _box_rest_position + Vector2(0.0, _box_slide_distance()), fade_time)
	_box_tween.chain().tween_callback(_on_box_faded_out)


func _on_box_faded_out() -> void:
	_reset_box_tween()
	hide()


func _reset_box_tween() -> void:
	if _box_tween != null and _box_tween.is_valid():
		_box_tween.kill()
		position = _box_rest_position
		modulate.a = 1.0
	_box_fading_out = false


func _fade_in_name_plate() -> void:
	if name_plate == null:
		return
	if _name_tween != null and _name_tween.is_valid():
		_name_tween.kill()
	name_plate.modulate.a = 1.0
	if not _animations_enabled():
		return
	name_plate.modulate.a = 0.0
	_name_tween = create_tween()
	_name_tween.tween_property(name_plate, "modulate:a", 1.0, _animation_time(NAME_FADE_TIME))


func _apply_seen_color() -> void:
	var ui_def: VNEngineUiDef = VNEngineMain.game().get_ui()
	if not _nvl_on and ui_def.mark_seen_text and VNEngineMain.settings().mark_read_text and runner != null and runner.line_seen_before:
		_active_label.add_theme_color_override("default_color", ui_def.seen_text_color)
	else:
		_active_label.remove_theme_color_override("default_color")


func _dialog_name_align() -> String:
	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()
	return ui_def.dialog_name_align


func _apply_name_plate_style(name_color: Color) -> void:
	if _name_plate_style == null:
		return
	_name_plate_style.border_color = name_color


func is_typing() -> bool:
	return _typing


func _on_text_finished() -> void:
	line_revealed.emit()
	if not runner.current_choices.is_empty():
		runner.is_auto = false
		runner.is_skip = false
		runner.mode_changed.emit()
		return

	_show_continue_indicator()

	if runner.is_skip:
		var serial: int = _line_serial
		get_tree().create_timer(0.2).timeout.connect(func():
			if serial == _line_serial and runner.is_skip:
				runner.next_node()
		)
	elif runner.is_auto:
		auto_timer.wait_time = VNEngineMain.settings().auto_speed
		auto_timer.start()


func _show_continue_indicator() -> void:
	var indicator: Label = nvl_page.continue_indicator if _nvl_on else continue_indicator
	if indicator == null:
		return
	indicator.show()
	indicator.modulate.a = 1.0
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(indicator, "modulate:a", 0.25, 0.6)
	_indicator_tween.tween_property(indicator, "modulate:a", 1.0, 0.6)


func _hide_continue_indicator() -> void:
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	nvl_page.continue_indicator.hide()
	if continue_indicator == null:
		return
	continue_indicator.hide()


func _on_mode_changed() -> void:
	if _typing:
		if runner.is_skip:
			_reveal_to_end()
		elif runner.is_auto and _at_click:
			_resume_from_click()
		return
	var current_node := runner.get_current_node()
	if current_node != null and runner.current_choices.is_empty():
		if not runner.is_auto:
			_cancel_voice_wait()
		if runner.is_auto and not runner.is_skip and _voice_playing():
			if not _voice_waiting:
				auto_timer.stop()
				_begin_voice_wait()
		elif runner.is_auto or runner.is_skip:
			auto_timer.stop()
			runner.next_node()


func _advance_dialog() -> void:
	if runner and runner.is_input_locked:
		return

	if runner and runner.is_skip:
		runner.is_skip = false
		runner.mode_changed.emit()

	if _typing:
		if runner and runner.is_auto:
			var advanced: bool = _reveal_to_end()
			if runner.is_auto and not advanced:
				auto_timer.stop()
				_cancel_voice_wait()
				runner.next_node()
		elif _at_click:
			_resume_from_click()
		else:
			_reveal_to_next_stop()
	else:
		_cancel_voice_wait()
		_line_serial += 1
		if runner:
			runner.next_node()


func _on_auto_timer_timeout() -> void:
	if not runner.is_auto:
		return
	if _voice_playing():
		_begin_voice_wait()
		return
	runner.next_node()


func _voice_playing() -> bool:
	if runner == null or runner.ctx == null or runner.ctx.audio == null:
		return false
	return runner.ctx.audio.is_channel_playing("voice")


func _cancel_voice_wait() -> void:
	_voice_waiting = false
	_voice_wait_id += 1


func _begin_voice_wait() -> void:
	var audio: VNEngineAudioSystem = runner.ctx.audio
	if not audio.channel_finished.is_connected(_on_channel_finished):
		audio.channel_finished.connect(_on_channel_finished)
	_voice_wait_id += 1
	_voice_wait_serial = _line_serial
	_voice_waiting = true


func _on_channel_finished(channel_name: String) -> void:
	if channel_name != "voice" or not _voice_waiting:
		return
	_voice_waiting = false
	if _voice_wait_serial != _line_serial or runner == null or not runner.is_auto:
		return
	var serial: int = _line_serial
	var wait_id: int = _voice_wait_id
	get_tree().create_timer(0.3, false).timeout.connect(func():
		if serial == _line_serial and wait_id == _voice_wait_id and runner.is_auto:
			runner.next_node()
	)


func _is_overlay_open() -> bool:
	return not VNEngineMain.instance().overlay_stack.is_empty()


func _is_input_locked() -> bool:
	return runner != null and (runner.is_input_locked or (runner.bus != null and runner.bus.has_pending_block()))


func _on_settings_changed() -> void:
	_apply_window_opacity()
	_restart_text_tween()
	if auto_timer:
		auto_timer.wait_time = VNEngineMain.settings().auto_speed


func _apply_window_opacity() -> void:
	if background_box == null:
		return
	var opacity: float = clampf(VNEngineMain.settings().window_opacity, 0.0, 1.0)
	background_box.self_modulate = Color(1.0, 1.0, 1.0, opacity)
	nvl_page.backdrop.self_modulate = Color(1.0, 1.0, 1.0, opacity)


func _restart_text_tween() -> void:
	if not _typing or _at_click:
		return
	_build_chain()


func _box_slide_distance() -> float:
	return 0.0 if _nvl_on else BOX_SLIDE_DISTANCE


func _on_text_mode_changed(mode: String) -> void:
	_switch_mode(mode == "nvl", true)


func _on_nvl_page_cleared() -> void:
	if _active_label != dialog_label:
		if _typing:
			_reset_reveal()
			_hide_continue_indicator()
		_active_label = dialog_label
	nvl_page.clear()


func _on_state_restored(_state: VNEngineStoryState) -> void:
	if runner.is_nvl() != _nvl_on:
		_switch_mode(runner.is_nvl(), true)
	if not _nvl_on:
		return
	_reset_reveal()
	_hide_continue_indicator()
	_active_label = dialog_label
	nvl_page.clear()
	_sync_nvl_page()


func _sync_nvl_page() -> void:
	if _active_label != dialog_label and is_instance_valid(_active_label):
		_active_label.remove_theme_color_override("default_color")
	var expected: Array[Dictionary] = runner.state.nvl_page
	if _same_entries(nvl_page.entries(), expected):
		return
	nvl_page.clear()
	for entry in expected:
		nvl_page.add_entry(String(entry.get("speaker", "")), String(entry.get("text", "")), String(entry.get("kind", "line")))


func _same_entries(shown: Array[Dictionary], expected: Array[Dictionary]) -> bool:
	if shown.size() != expected.size():
		return false
	for i in shown.size():
		for key in ["speaker", "text", "kind"]:
			if String(shown[i].get(key, "")) != String(expected[i].get(key, "")):
				return false
	return true


func _switch_mode(nvl: bool, animate: bool) -> void:
	if _mode_tween != null and _mode_tween.is_valid():
		_mode_tween.kill()
		_settle_mode_visuals()
	_reset_reveal()
	_hide_continue_indicator()
	_nvl_on = nvl
	_active_label = dialog_label
	var fade: bool = animate and visible and _animations_enabled()
	var time: float = _animation_time(MODE_FADE_TIME)
	if nvl:
		nvl_page.clear()
		nvl_page.show()
		if fade:
			nvl_page.modulate.a = 0.0
			_mode_tween = create_tween().set_parallel(true)
			_mode_tween.tween_property(nvl_page, "modulate:a", 1.0, time)
			_mode_tween.tween_property(background_box, "modulate:a", 0.0, time)
			_mode_tween.tween_property(name_row, "modulate:a", 0.0, time)
			_mode_tween.chain().tween_callback(_settle_mode_visuals)
			return
	else:
		background_box.show()
		if fade:
			background_box.modulate.a = 0.0
			name_row.modulate.a = 0.0
			_mode_tween = create_tween().set_parallel(true)
			_mode_tween.tween_property(background_box, "modulate:a", 1.0, time)
			_mode_tween.tween_property(name_row, "modulate:a", 1.0, time)
			_mode_tween.tween_property(nvl_page, "modulate:a", 0.0, time)
			_mode_tween.chain().tween_callback(_settle_mode_visuals)
			return
	_settle_mode_visuals()


func _settle_mode_visuals() -> void:
	nvl_page.modulate.a = 1.0
	background_box.modulate.a = 1.0
	name_row.modulate.a = 1.0
	nvl_page.visible = _nvl_on
	background_box.visible = not _nvl_on
	if _nvl_on:
		name_row.hide()
		dialog_label.text = ""
		speaker_label.text = ""
		_last_speaker_text = ""
	else:
		nvl_page.clear()
