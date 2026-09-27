class_name VNEngineControlsPage
extends ScrollContainer

const _ROW_SEPARATION: int = 20
const _LABEL_MIN_WIDTH: int = 340
const _SLOT_MIN_SIZE: Vector2 = Vector2(220, 48)
const _CAPTURE_STATUS: String = "Press a key... (Esc to cancel)"

var _rows_box: VBoxContainer
var _status_label: Label
var _slot_buttons: Dictionary = {}

var _capturing: bool = false
var _capture_action: StringName = &""
var _capture_slot: int = -1


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", _ROW_SEPARATION)
	add_child(_rows_box)

	for action: StringName in VNEngineInput.ACTIONS:
		_rows_box.add_child(_build_action_row(action))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	_rows_box.add_child(footer)

	var reset_all_btn := Button.new()
	reset_all_btn.text = "Reset all keys"
	reset_all_btn.pressed.connect(_on_reset_all_pressed)
	footer.add_child(reset_all_btn)

	_status_label = Label.new()
	_status_label.theme_type_variation = &"VNSmallLabel"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status_label)

	VNEngineMain.settings().changed.connect(_on_settings_changed)

	refresh()


func _input(event: InputEvent) -> void:
	if not _capturing:
		return
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return

	get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel_capture()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cancel_capture()
		return
	if not VNEngineInput.is_bindable(event):
		return

	_try_rebind(event)


func refresh() -> void:
	for action: StringName in VNEngineInput.ACTIONS:
		var buttons: Array = _slot_buttons.get(action, [])
		if buttons.is_empty():
			continue
		var events: Array[InputEvent] = VNEngineInput.get_events(action)
		for slot: int in 2:
			var btn: Button = buttons[slot]
			if _capturing and _capture_action == action and _capture_slot == slot:
				btn.text = "..."
				continue
			if slot < events.size():
				btn.text = VNEngineInput.event_label(events[slot])
			else:
				btn.text = "-"


func is_capturing() -> bool:
	return _capturing


func cancel_capture() -> void:
	if not _capturing:
		return
	_capturing = false
	_capture_action = &""
	_capture_slot = -1
	_set_status("")
	refresh()


func _build_action_row(action: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = String(action) + "Row"
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.custom_minimum_size = Vector2(_LABEL_MIN_WIDTH, 0)
	label.text = String(VNEngineInput.LABELS.get(action, action))
	row.add_child(label)

	var slot0 := Button.new()
	slot0.custom_minimum_size = _SLOT_MIN_SIZE
	slot0.pressed.connect(_on_slot_button_pressed.bind(action, 0))
	row.add_child(slot0)

	var slot1 := Button.new()
	slot1.custom_minimum_size = _SLOT_MIN_SIZE
	slot1.pressed.connect(_on_slot_button_pressed.bind(action, 1))
	row.add_child(slot1)

	var reset_btn := Button.new()
	reset_btn.theme_type_variation = &"VNSmallButton"
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(_on_reset_action_pressed.bind(action))
	row.add_child(reset_btn)

	_slot_buttons[action] = [slot0, slot1]
	return row


func _try_rebind(event: InputEvent) -> void:
	var conflict: StringName = VNEngineInput.rebind(_capture_action, _capture_slot, event)
	if conflict != &"":
		var conflict_label: String = String(VNEngineInput.LABELS.get(conflict, conflict))
		_set_status("Already used by %s" % conflict_label)
		return

	_capturing = false
	_capture_action = &""
	_capture_slot = -1
	_set_status("")
	refresh()


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _on_slot_button_pressed(action: StringName, slot: int) -> void:
	_capture_action = action
	_capture_slot = slot
	_capturing = true
	_set_status(_CAPTURE_STATUS)
	refresh()


func _on_reset_action_pressed(action: StringName) -> void:
	if _capturing:
		cancel_capture()
	VNEngineInput.reset(action)
	refresh()


func _on_reset_all_pressed() -> void:
	if _capturing:
		cancel_capture()
	VNEngineInput.reset_all()
	refresh()


func _on_settings_changed() -> void:
	refresh()
