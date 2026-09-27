class_name VNEngineChoiceUI
extends Control

@export var runner: VNEngineStoryRunner
@export var button_container: VBoxContainer

var _choice_timer: Timer = null
var _choice_timer_target: VNEngineChoiceOption = null
var _choice_timer_bar: ProgressBar = null
var _choice_timer_label: Label = null


func _ready() -> void:
	hide()

	if runner:
		runner.choices_requested.connect(_on_choices_requested)
		runner.state_restored.connect(_on_state_restored)

	_choice_timer = Timer.new()
	_choice_timer.one_shot = true
	add_child(_choice_timer)
	_choice_timer.timeout.connect(_on_choice_timer_timeout)

	var timer_bar_node: Node = get_node_or_null("%ChoiceTimerBar")
	_choice_timer_bar = timer_bar_node as ProgressBar
	var timer_label_node: Node = get_node_or_null("%ChoiceTimerLabel")
	_choice_timer_label = timer_label_node as Label
	if _choice_timer_bar:
		_choice_timer_bar.step = 0.01
		_choice_timer_bar.hide()
	if _choice_timer_label:
		_choice_timer_label.hide()


func _process(_delta: float) -> void:
	if _choice_timer == null or _choice_timer.is_stopped():
		return
	var remaining: float = _choice_timer.time_left
	if _choice_timer_label:
		_choice_timer_label.text = "%.1f" % remaining
	if _choice_timer_bar:
		_choice_timer_bar.value = remaining


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
	var visible_choices: Array[VNEngineChoiceOption] = []

	var box_width: float = 1100.0
	if button_container:
		box_width = button_container.custom_minimum_size.x
	var content_width := maxf(box_width - 32.0, 10.0)

	for choice in choices:
		if choice.once and runner and runner.state and runner.state.seen_choices.has(_choice_key(choice)):
			continue

		if choice.condition != "" and not VNEngineExpressionEvaluator.evaluate(choice.condition, vars):
			continue

		visible_choices.append(choice)

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

	if not choice_timer_data.is_empty() and not visible_choices.is_empty():
		var timer_seconds: float = float(choice_timer_data.get("seconds", 0.0))
		var default_index: int = int(choice_timer_data.get("default_index", 0))
		if default_index < 0 or default_index >= visible_choices.size():
			VNEngineLog.warn("ChoiceUI", "'@choice_timer' default_index (%d) is out of range, clamping to the last choice" % default_index)
			default_index = visible_choices.size() - 1

		_choice_timer_target = visible_choices[default_index]
		_choice_timer.wait_time = timer_seconds
		_choice_timer.start()

		if _choice_timer_bar:
			_choice_timer_bar.max_value = timer_seconds
			_choice_timer_bar.value = timer_seconds
			_choice_timer_bar.show()
		if _choice_timer_label:
			_choice_timer_label.text = "%.1f" % timer_seconds
			_choice_timer_label.show()

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
		runner.state.seen_choices[_choice_key(choice)] = true

	if runner:
		runner.make_choice(choice.target_index)


func _clear_buttons() -> void:
	if _choice_timer:
		_choice_timer.stop()
	_choice_timer_target = null
	if _choice_timer_bar:
		_choice_timer_bar.hide()
	if _choice_timer_label:
		_choice_timer_label.hide()
	for child in button_container.get_children():
		child.queue_free()


func _choice_key(choice: VNEngineChoiceOption) -> String:
	var file := ""
	if runner and runner.state:
		file = runner.state.current_file
	return "%s:%d" % [file, choice.line]


func _on_choice_timer_timeout() -> void:
	if _choice_timer_target == null:
		return
	var target: VNEngineChoiceOption = _choice_timer_target
	_choice_timer_target = null
	_on_button_pressed(target)
