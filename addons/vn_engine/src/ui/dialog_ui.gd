class_name VNEngineDialogUI
extends Control

const NAME_COLOR_FALLBACK: Color = Color.WHITE

@export var runner: VNEngineStoryRunner
@export var dialog_label: RichTextLabel
@export var speaker_label: Label
@export var in_game_buttons: VNEngineInGameButtons
@export var choice_ui_root: Control

var is_ui_hidden: bool = false

var _text_tween: Tween
var _indicator_tween: Tween

var _skip_via_hold: bool = false

var _name_plate_style: StyleBoxFlat

@onready var auto_timer: Timer = $AutoTimer
@onready var background_box: Panel = $BackgroundBox
@onready var name_row: HBoxContainer = $NameRow
@onready var name_plate: PanelContainer = $NameRow/NamePlate
@onready var continue_indicator: Label = $ContinueIndicator


func _ready() -> void:
	hide()

	if runner:
		runner.register_manager(self)
		runner.dialog_started.connect(_on_dialog_started)
		runner.story_ended.connect(_on_story_ended)
		runner.mode_changed.connect(_on_mode_changed)

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

	VNEngineMain.settings().changed.connect(_on_settings_changed)
	_apply_window_opacity()

	var vn_main: VNEngineMain = VNEngineMain.instance()
	var card_overlay: VNEngineCardOverlay = vn_main.get_card_overlay() if vn_main != null else null
	if card_overlay != null:
		card_overlay.covered.connect(clear_text)


func toggle_ui() -> void:
	is_ui_hidden = !is_ui_hidden

	visible = !is_ui_hidden

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

	show()
	_hide_continue_indicator()

	if node.text == "" and not node.choices.is_empty():
		_show_choice_prompt()
		return

	_apply_speaker(node.speaker_id)

	dialog_label.visible_characters = 0

	dialog_label.text = node.text

	_maybe_play_auto_voice(node)

	if _text_tween and _text_tween.is_valid():
		_text_tween.kill()

	_text_tween = create_tween()
	var total_chars: int = dialog_label.get_parsed_text().length()

	var current_speed: float = VNEngineMain.settings().text_speed
	var duration: float = maxf(total_chars * current_speed, 0.01)

	if runner.is_skip:
		duration = duration / 10.0

	_text_tween.tween_property(dialog_label, "visible_characters", total_chars, duration)
	_text_tween.tween_callback(_on_text_finished)


func _apply_speaker(speaker_id: String) -> void:
	var speaker_text: String = "" if _is_narrator(speaker_id) else _speaker_name(speaker_id)
	if speaker_text == "":
		speaker_label.text = ""
		if name_row:
			name_row.hide()
	else:
		speaker_label.text = speaker_text
		var name_color: Color = _speaker_name_color(speaker_id)
		speaker_label.add_theme_color_override("font_color", name_color)
		_apply_name_plate_style(name_color)
		if name_row:
			name_row.show()


func clear_text() -> void:
	if _text_tween and _text_tween.is_valid():
		_text_tween.kill()
	auto_timer.stop()
	_hide_continue_indicator()
	dialog_label.text = ""
	speaker_label.text = ""
	if name_row:
		name_row.hide()


func _show_choice_prompt() -> void:
	if _text_tween and _text_tween.is_valid():
		_text_tween.kill()

	var history: Array[Dictionary] = []
	if runner and runner.state:
		history = runner.state.history
	for i in range(history.size() - 1, -1, -1):
		var entry: Dictionary = history[i]
		var text: String = String(entry.get("text", ""))
		if text == "":
			continue
		_apply_speaker(String(entry.get("speaker", "")))
		dialog_label.text = text
		break

	dialog_label.visible_characters = -1
	_on_text_finished()


func _on_story_ended() -> void:
	hide()
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
		if String(cmd.get("name", "")) == "voice":
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


func _speaker_name_color(speaker_id: String) -> Color:
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


func _dialog_name_align() -> String:
	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()
	return ui_def.dialog_name_align


func _apply_name_plate_style(name_color: Color) -> void:
	if _name_plate_style == null:
		return
	_name_plate_style.border_color = name_color


func _on_text_finished() -> void:
	var current_node := runner.get_current_node()
	if current_node != null and not current_node.choices.is_empty():
		runner.is_auto = false
		runner.is_skip = false
		runner.mode_changed.emit()
		return

	_show_continue_indicator()

	if runner.is_skip:
		get_tree().create_timer(0.2).timeout.connect(func():
			if runner.is_skip:
				runner.next_node()
		)
	elif runner.is_auto:
		auto_timer.wait_time = VNEngineMain.settings().auto_speed
		auto_timer.start()


func _show_continue_indicator() -> void:
	if continue_indicator == null:
		return
	continue_indicator.show()
	continue_indicator.modulate.a = 1.0
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 0.25, 0.6)
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.6)


func _hide_continue_indicator() -> void:
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	if continue_indicator == null:
		return
	continue_indicator.hide()


func _on_mode_changed() -> void:
	if _text_tween != null and _text_tween.is_valid() and _text_tween.is_running():
		return
	var current_node := runner.get_current_node()
	if current_node != null and current_node.choices.is_empty():
		if runner.is_auto or runner.is_skip:
			auto_timer.stop()
			runner.next_node()


func _advance_dialog() -> void:
	if runner and runner.is_input_locked:
		return

	if runner and runner.is_skip:
		runner.is_skip = false
		runner.mode_changed.emit()

	if _text_tween and _text_tween.is_running():
		_text_tween.custom_step(100.0)

		if runner and runner.is_auto:
			auto_timer.stop()
			runner.next_node()
	else:
		if runner:
			runner.next_node()


func _on_auto_timer_timeout() -> void:
	if runner.is_auto:
		runner.next_node()


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


func _restart_text_tween() -> void:
	if _text_tween == null or not _text_tween.is_valid() or not _text_tween.is_running():
		return

	var total_chars: int = dialog_label.get_parsed_text().length()
	var current_visible: int = maxi(dialog_label.visible_characters, 0)
	if current_visible >= total_chars:
		return

	_text_tween.kill()

	var current_speed: float = VNEngineMain.settings().text_speed
	var remaining_chars: int = total_chars - current_visible
	var duration: float = maxf(remaining_chars * current_speed, 0.01)
	if runner != null and runner.is_skip:
		duration = duration / 10.0

	_text_tween = create_tween()
	_text_tween.tween_property(dialog_label, "visible_characters", total_chars, duration)
	_text_tween.tween_callback(_on_text_finished)
