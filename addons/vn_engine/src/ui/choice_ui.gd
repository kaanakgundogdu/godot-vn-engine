class_name VNEngineChoiceUI
extends Control

const ENTER_TIME: float = 0.18
const ENTER_STAGGER: float = 0.05
const ENTER_SLIDE_DISTANCE: float = 16.0
const HOVER_SCALE: float = 1.03
const HOVER_TIME: float = 0.1
const PICK_GLOW_TIME: float = 0.12
const PICK_GLOW_COLOR: Color = Color(1.3, 1.3, 1.3)
const OTHERS_FADE_TIME: float = 0.15
const CHOSEN_DIM: Color = Color(0.65, 0.65, 0.65)
const NVL_LIT: Color = Color(1.35, 1.35, 1.35)
const NVL_DISABLED_ALPHA: float = 0.45
const NVL_ROW_PAD: float = 4.0
const NVL_DIAL_SIZE: Vector2 = Vector2(64, 64)
const NVL_LINE_SEPARATION: int = 6
const DIAL_SIZE: Vector2 = Vector2(88, 88)

@export var runner: VNEngineStoryRunner
@export var button_container: VBoxContainer

var _choice_timer: Timer = null
var _choice_timer_target: VNEngineChoiceOption = null
var _timer_dial: VNEngineChoiceTimerDial = null
var _choice_timer_waiting: bool = false
var _choice_buttons: Dictionary = {}
var _enter_tween: Tween
var _pick_tween: Tween
var _is_locked: bool = false
var _build_id: int = 0
var _nvl_box: VBoxContainer = null
var _nvl_texts: Dictionary = {}


func _ready() -> void:
	hide()

	if runner:
		runner.choices_requested.connect(_on_choices_requested)
		runner.state_restored.connect(_on_state_restored)

	_choice_timer = Timer.new()
	_choice_timer.one_shot = true
	add_child(_choice_timer, false, Node.INTERNAL_MODE_FRONT)
	_choice_timer.timeout.connect(_on_choice_timer_timeout)

	_timer_dial = VNEngineChoiceTimerDial.new()
	_timer_dial.hide()
	add_child(_timer_dial, false, Node.INTERNAL_MODE_FRONT)


func _process(_delta: float) -> void:
	if _choice_timer == null or _choice_timer.is_stopped():
		return
	_timer_dial.set_time(_choice_timer.time_left, _choice_timer.wait_time)


func _on_state_restored(_state: VNEngineStoryState) -> void:
	hide()
	_clear_buttons()


func _on_choices_requested(choices: Array[VNEngineChoiceOption]) -> void:
	var choice_timer_data: Dictionary = {}
	if runner:
		choice_timer_data = runner.pending_choice_timer
		runner.pending_choice_timer = {}

	_clear_buttons()
	_build_id += 1
	var build_id: int = _build_id
	var ui_def: VNEngineUiDef = VNEngineMain.game().get_ui()
	var chapter_id: String = runner.script_res.chapter_id if runner != null and runner.script_res != null else ""
	var save_data: VNEngineSaveData = VNEngineMain.save_data()

	var vars: Dictionary = {}
	if runner and runner.state:
		vars = runner.state.flags

	var created_labels: Array[RichTextLabel] = []
	var nvl_page: VNEngineNvlPage = null
	if runner != null and runner.is_nvl() and runner.ctx != null and runner.ctx.dialog_ui != null:
		nvl_page = runner.ctx.dialog_ui.nvl_page

	var box_width: float = 1100.0
	if button_container:
		box_width = button_container.custom_minimum_size.x
	var content_width := maxf(box_width - 32.0, 10.0)

	for choice in choices:
		if nvl_page != null:
			var nvl_text: String = VNEngineTextMarkup.strip(VNEngineTextMarkup.interpolate(choice.text, vars))
			var nvl_btn: Button = _make_nvl_button(choice, nvl_text, vars, ui_def, chapter_id, save_data, created_labels)
			_nvl_box = nvl_page.choice_container()
			_nvl_box.add_child(nvl_btn)
			_nvl_texts[choice] = nvl_text
			_choice_buttons[choice] = nvl_btn
			continue
		var btn := Button.new()
		btn.text = ""
		btn.custom_minimum_size.y = 72
		btn.custom_minimum_size.x = box_width
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ui_def.ui_animations:
			btn.modulate.a = 0.0

		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = VNEngineTextMarkup.strip(VNEngineTextMarkup.interpolate(choice.text, vars))
		if ui_def.mark_chosen_choices and save_data != null and choice.line_id != "" and save_data.is_choice_chosen(chapter_id, choice.line_id):
			label.modulate = CHOSEN_DIM
		label.custom_minimum_size.x = content_width
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
		btn.add_child(label)
		created_labels.append(label)

		if choice.disabled_if != "" and VNEngineExpressionEvaluator.evaluate(choice.disabled_if, vars):
			btn.disabled = true

		btn.pressed.connect(_on_button_pressed.bind(choice))
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))
		button_container.add_child(btn)
		_choice_buttons[choice] = btn

	if not choice_timer_data.is_empty() and not choices.is_empty():
		var timer_seconds: float = float(choice_timer_data.get("seconds", 0.0))
		var default_index: int = int(choice_timer_data.get("default_index", 0))
		if default_index < 0 or default_index >= choices.size():
			VNEngineLog.warn("ChoiceUI", "'@choice_timer' default_index (%d) is out of range, clamping to the last choice" % default_index)
			default_index = choices.size() - 1

		_choice_timer_target = choices[default_index]
		_choice_timer.wait_time = timer_seconds

		var dialog: VNEngineDialogUI = runner.ctx.dialog_ui if runner != null and runner.ctx != null else null
		if dialog != null and dialog.is_typing() and not runner.is_skip:
			_choice_timer_waiting = true
			if not dialog.line_revealed.is_connected(_on_line_revealed):
				dialog.line_revealed.connect(_on_line_revealed)
		else:
			_choice_timer.start()

		_timer_dial.set_time(timer_seconds, timer_seconds)
		if nvl_page != null:
			_timer_dial.custom_minimum_size = NVL_DIAL_SIZE
			_timer_dial.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			remove_child(_timer_dial)
			_nvl_box.add_child(_timer_dial)
		_timer_dial.show()

	if nvl_page != null:
		hide()
		await get_tree().process_frame
		if build_id != _build_id:
			return
		for label in created_labels:
			var nvl_btn := label.get_parent() as Button
			if nvl_btn:
				nvl_btn.custom_minimum_size.y = label.get_content_height() + NVL_ROW_PAD
		if ui_def.ui_animations:
			await get_tree().process_frame
			if build_id == _build_id and not _is_locked:
				_play_nvl_enter_animation(ui_def.ui_animation_scale)
		return

	await get_tree().process_frame
	for label in created_labels:
		var btn := label.get_parent() as Button
		if btn:
			btn.custom_minimum_size.y = maxf(72.0, label.get_content_height() + 32.0)

	show.call_deferred()

	if ui_def.ui_animations:
		await get_tree().process_frame
		if build_id == _build_id and not _is_locked:
			_play_enter_animation(ui_def.ui_animation_scale)


func _make_nvl_button(choice: VNEngineChoiceOption, text: String, vars: Dictionary, ui_def: VNEngineUiDef, chapter_id: String, save_data: VNEngineSaveData, labels: Array[RichTextLabel]) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 24.0
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("line_separation", NVL_LINE_SEPARATION)
	label.text = "> " + text
	if ui_def.mark_chosen_choices and save_data != null and choice.line_id != "" and save_data.is_choice_chosen(chapter_id, choice.line_id):
		label.modulate = CHOSEN_DIM
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(label)
	labels.append(label)

	if choice.disabled_if != "" and VNEngineExpressionEvaluator.evaluate(choice.disabled_if, vars):
		btn.disabled = true
	if ui_def.ui_animations:
		btn.modulate.a = 0.0
	_refresh_nvl_button(btn)

	btn.pressed.connect(_on_button_pressed.bind(choice))
	var refresh: Callable = _refresh_nvl_button.bind(btn)
	btn.mouse_entered.connect(refresh)
	btn.mouse_exited.connect(refresh)
	btn.focus_entered.connect(refresh)
	btn.focus_exited.connect(refresh)
	return btn


func _refresh_nvl_button(btn: Button) -> void:
	var alpha: float = btn.modulate.a
	if btn.disabled:
		btn.modulate = Color(1.0, 1.0, 1.0, minf(alpha, NVL_DISABLED_ALPHA))
		return
	var tint: Color = NVL_LIT if (btn.is_hovered() or btn.has_focus()) else Color.WHITE
	btn.modulate = Color(tint.r, tint.g, tint.b, alpha)


func _play_nvl_enter_animation(time_scale: float) -> void:
	var index: int = 0
	_enter_tween = create_tween().set_parallel(true)
	for btn: Button in _choice_buttons.values():
		var target_alpha: float = NVL_DISABLED_ALPHA if btn.disabled else 1.0
		_enter_tween.tween_property(btn, "modulate:a", target_alpha, ENTER_TIME * time_scale).set_delay(index * ENTER_STAGGER * time_scale)
		index += 1


func _play_enter_animation(time_scale: float) -> void:
	var index: int = 0
	_enter_tween = create_tween().set_parallel(true)
	for btn: Button in button_container.get_children():
		var rest_x: float = btn.position.x
		btn.position.x = rest_x + ENTER_SLIDE_DISTANCE
		var delay: float = index * ENTER_STAGGER * time_scale
		var time: float = ENTER_TIME * time_scale
		_enter_tween.tween_property(btn, "modulate:a", 1.0, time).set_delay(delay)
		_enter_tween.tween_property(btn, "position:x", rest_x, time).set_delay(delay)
		index += 1


func _on_button_hover(btn: Button, hovered: bool) -> void:
	var ui_def: VNEngineUiDef = VNEngineMain.game().get_ui()
	if _is_locked or btn.disabled or not ui_def.ui_animations:
		return
	if btn.has_meta("hover_tween"):
		var previous: Tween = btn.get_meta("hover_tween")
		if previous != null and previous.is_valid():
			previous.kill()
	btn.pivot_offset = btn.size / 2.0
	var target: float = HOVER_SCALE if hovered else 1.0
	var hover_tween: Tween = btn.create_tween()
	hover_tween.tween_property(btn, "scale", Vector2(target, target), HOVER_TIME * ui_def.ui_animation_scale)
	btn.set_meta("hover_tween", hover_tween)


func _on_button_pressed(choice: VNEngineChoiceOption) -> void:
	if _is_locked:
		return
	_is_locked = true

	_choice_timer.stop()
	_choice_timer_waiting = false
	_choice_timer_target = null
	_timer_dial.hide()

	if choice.once and runner and runner.state:
		runner.state.seen_choices[runner.choice_key(choice)] = true

	var save_data: VNEngineSaveData = VNEngineMain.save_data()
	if save_data != null and choice.line_id != "" and runner != null and runner.script_res != null:
		save_data.mark_choice_chosen(runner.script_res.chapter_id, choice.line_id)

	var ui_def: VNEngineUiDef = VNEngineMain.game().get_ui()
	var picked: Button = _choice_buttons.get(choice)
	if not ui_def.ui_animations or picked == null or _nvl_box != null:
		_finish_choice(choice)
		return

	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	for btn: Button in _choice_buttons.values():
		btn.disabled = true
		btn.modulate.a = 1.0

	_pick_tween = create_tween().set_parallel(true)
	_pick_tween.tween_property(picked, "modulate", PICK_GLOW_COLOR, PICK_GLOW_TIME * ui_def.ui_animation_scale)
	for btn: Button in _choice_buttons.values():
		if btn != picked:
			_pick_tween.tween_property(btn, "modulate:a", 0.0, OTHERS_FADE_TIME * ui_def.ui_animation_scale)
	_pick_tween.chain().tween_callback(_finish_choice.bind(choice))


func _finish_choice(choice: VNEngineChoiceOption) -> void:
	hide()
	var nvl_text: String = String(_nvl_texts.get(choice, ""))
	var was_nvl: bool = _nvl_box != null
	_clear_buttons()
	if was_nvl and runner:
		runner.add_nvl_choice(nvl_text)
		var dialog: VNEngineDialogUI = runner.ctx.dialog_ui if runner.ctx != null else null
		if dialog != null and dialog.nvl_page != null:
			dialog.nvl_page.add_entry("", nvl_text, "choice")
	if runner:
		runner.make_choice(choice.target_index)


func _on_line_revealed() -> void:
	if not _choice_timer_waiting:
		return
	_choice_timer_waiting = false
	_choice_timer.start()


func _clear_buttons() -> void:
	_choice_timer_waiting = false
	_is_locked = false
	_choice_buttons.clear()
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	if _pick_tween != null and _pick_tween.is_valid():
		_pick_tween.kill()
	if _choice_timer:
		_choice_timer.stop()
	_choice_timer_target = null
	_timer_dial.hide()
	if _timer_dial.get_parent() != self:
		if _timer_dial.get_parent() != null:
			_timer_dial.get_parent().remove_child(_timer_dial)
		add_child(_timer_dial, false, Node.INTERNAL_MODE_FRONT)
		_timer_dial.custom_minimum_size = DIAL_SIZE
		_timer_dial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _nvl_box != null and is_instance_valid(_nvl_box):
		for child in _nvl_box.get_children():
			_nvl_box.remove_child(child)
			child.queue_free()
	_nvl_box = null
	_nvl_texts.clear()
	for child in button_container.get_children():
		child.queue_free()


func _on_choice_timer_timeout() -> void:
	if _choice_timer_target == null:
		return
	var target: VNEngineChoiceOption = _choice_timer_target
	_choice_timer_target = null
	_on_button_pressed(target)
