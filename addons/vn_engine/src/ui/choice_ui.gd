class_name VNEngineChoiceUI
extends Control

@export var runner: VNEngineStoryRunner
@export var button_container: VBoxContainer

var _choice_timer: Timer = null
var _choice_timer_target: VNEngineChoiceOption = null
var _timer_dial: VNEngineChoiceTimerDial = null
var _choice_timer_waiting: bool = false


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

	var vars: Dictionary = {}
	if runner and runner.state:
		vars = runner.state.flags

	var created_labels: Array[RichTextLabel] = []

	var box_width: float = 1100.0
	if button_container:
		box_width = button_container.custom_minimum_size.x
	var content_width := maxf(box_width - 32.0, 10.0)

	for choice in choices:
		var btn := Button.new()
		btn.text = ""
		btn.custom_minimum_size.y = 72
		btn.custom_minimum_size.x = box_width
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = choice.text
		label.custom_minimum_size.x = content_width
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
		btn.add_child(label)
		created_labels.append(label)

		if choice.disabled_if != "" and VNEngineExpressionEvaluator.evaluate(choice.disabled_if, vars):
			btn.disabled = true

		btn.pressed.connect(_on_button_pressed.bind(choice))
		button_container.add_child(btn)

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
		_timer_dial.show()

	await get_tree().process_frame
	for label in created_labels:
		var btn := label.get_parent() as Button
		if btn:
			btn.custom_minimum_size.y = maxf(72.0, label.get_content_height() + 32.0)

	show.call_deferred()


func _on_button_pressed(choice: VNEngineChoiceOption) -> void:
	hide()
	_clear_buttons()

	if choice.once and runner and runner.state:
		runner.state.seen_choices[runner.choice_key(choice)] = true

	if runner:
		runner.make_choice(choice.target_index)


func _on_line_revealed() -> void:
	if not _choice_timer_waiting:
		return
	_choice_timer_waiting = false
	_choice_timer.start()


func _clear_buttons() -> void:
	_choice_timer_waiting = false
	if _choice_timer:
		_choice_timer.stop()
	_choice_timer_target = null
	_timer_dial.hide()
	for child in button_container.get_children():
		child.queue_free()


func _on_choice_timer_timeout() -> void:
	if _choice_timer_target == null:
		return
	var target: VNEngineChoiceOption = _choice_timer_target
	_choice_timer_target = null
	_on_button_pressed(target)
