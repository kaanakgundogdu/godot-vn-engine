@tool
class_name VNEngineInput
extends RefCounted

const ADVANCE := &"vn_advance"
const HIDE_UI := &"vn_hide_ui"
const ALT_CLICK := &"vn_alt_click"
const ROLLBACK := &"vn_rollback"
const FORWARD := &"vn_forward"
const QUICKSAVE := &"vn_quicksave"
const QUICKLOAD := &"vn_quickload"
const SKIP_HOLD := &"vn_skip_hold"
const AUTO_TOGGLE := &"vn_auto_toggle"
const OPEN_LOG := &"vn_open_log"

const ACTIONS: Array[StringName] = [ADVANCE, AUTO_TOGGLE, SKIP_HOLD, HIDE_UI, OPEN_LOG, ROLLBACK, FORWARD, QUICKSAVE, QUICKLOAD, ALT_CLICK]
const LABELS: Dictionary = {ADVANCE: "Advance", AUTO_TOGGLE: "Auto mode", SKIP_HOLD: "Skip (hold)", HIDE_UI: "Hide UI", OPEN_LOG: "Open log", ROLLBACK: "Rollback", FORWARD: "Forward", QUICKSAVE: "Quick save", QUICKLOAD: "Quick load", ALT_CLICK: "Alt click"}

static var _baseline: Dictionary = {}


static func register_defaults() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			for event: InputEvent in default_events(action):
				InputMap.action_add_event(action, event)
	if _baseline.is_empty():
		for action: StringName in ACTIONS:
			_baseline[action] = _duplicate_events(get_events(action))


static func default_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	match action:
		ADVANCE:
			events.append(_key_event(KEY_SPACE))
			events.append(_key_event(KEY_ENTER))
			events.append(_key_event(KEY_KP_ENTER))
		HIDE_UI:
			events.append(_key_event(KEY_H))
		ALT_CLICK:
			events.append(_mouse_event(MOUSE_BUTTON_RIGHT))
		ROLLBACK:
			events.append(_mouse_event(MOUSE_BUTTON_WHEEL_UP))
		FORWARD:
			events.append(_mouse_event(MOUSE_BUTTON_WHEEL_DOWN))
		QUICKSAVE:
			events.append(_key_event(KEY_F5))
		QUICKLOAD:
			events.append(_key_event(KEY_F9))
		SKIP_HOLD:
			events.append(_key_event(KEY_CTRL))
		AUTO_TOGGLE:
			events.append(_key_event(KEY_A))
		OPEN_LOG:
			events.append(_key_event(KEY_L))
	return events


static func get_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		events.append(event)
	return events


static func rebind(action: StringName, slot: int, event: InputEvent) -> StringName:
	event = _clean_event(event)
	if event == null:
		return &""
	for other_action: StringName in ACTIONS:
		if other_action == action:
			continue
		for other_event: InputEvent in get_events(other_action):
			if _same_input(other_event, event):
				return other_action

	var events: Array[InputEvent] = get_events(action)
	for i: int in range(events.size()):
		if i != slot and _same_input(events[i], event):
			return &""

	if slot < events.size():
		events[slot] = event
	else:
		events.append(event)

	InputMap.action_erase_events(action)
	for e: InputEvent in events:
		InputMap.action_add_event(action, e)
	return &""


static func reset(action: StringName) -> void:
	if not _baseline.has(action):
		return
	InputMap.action_erase_events(action)
	for event: InputEvent in _baseline[action]:
		InputMap.action_add_event(action, event)


static func reset_all() -> void:
	for action: StringName in ACTIONS:
		reset(action)


static func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		var keycode: Key = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		return keycode != KEY_ESCAPE and keycode != KEY_F3
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index != MOUSE_BUTTON_LEFT
	if event is InputEventJoypadButton:
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		return joy_event.pressed
	return false


static func event_label(event: InputEvent) -> String:
	if event == null:
		return ""
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var pk: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if DisplayServer.get_name() == "headless":
			return OS.get_keycode_string(pk)
		var keycode: Key = DisplayServer.keyboard_get_keycode_from_physical(pk)
		if keycode == KEY_NONE:
			return OS.get_keycode_string(pk)
		return OS.get_keycode_string(keycode)
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "Left Click"
			MOUSE_BUTTON_RIGHT:
				return "Right Click"
			MOUSE_BUTTON_MIDDLE:
				return "Middle Click"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel Down"
			_:
				return "Mouse %d" % mouse_event.button_index
	if event is InputEventJoypadButton:
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		return "Pad %d" % joy_event.button_index
	return ""


static func export_overrides() -> Dictionary:
	var overrides: Dictionary = {}
	for action: StringName in ACTIONS:
		var events: Array[InputEvent] = get_events(action)
		var baseline_events: Array[InputEvent] = _baseline.get(action, [])
		if _events_equal(events, baseline_events):
			continue
		var entries: Array = []
		for event: InputEvent in events:
			var entry: Dictionary = _event_to_dict(event)
			if not entry.is_empty():
				entries.append(entry)
		overrides[String(action)] = entries
	return overrides


static func apply_overrides(overrides: Dictionary) -> void:
	reset_all()
	for action: StringName in ACTIONS:
		var key: String = String(action)
		if not overrides.has(key):
			continue
		var entries: Variant = overrides[key]
		if not entries is Array or entries.is_empty():
			continue
		var events: Array[InputEvent] = []
		for entry: Variant in entries:
			if not entry is Dictionary:
				continue
			var event: InputEvent = _event_from_dict(entry)
			if event != null:
				events.append(event)
		if events.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in events:
			InputMap.action_add_event(action, event)


static func _key_event(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _mouse_event(button_index: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	return event


static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var key_a: InputEventKey = a as InputEventKey
		var key_b: InputEventKey = b as InputEventKey
		return _key_code(key_a) == _key_code(key_b)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		var mouse_a: InputEventMouseButton = a as InputEventMouseButton
		var mouse_b: InputEventMouseButton = b as InputEventMouseButton
		return mouse_a.button_index == mouse_b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		var joy_a: InputEventJoypadButton = a as InputEventJoypadButton
		var joy_b: InputEventJoypadButton = b as InputEventJoypadButton
		return joy_a.button_index == joy_b.button_index
	return false


static func _key_code(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != 0 else event.keycode


static func _clean_event(event: InputEvent) -> InputEvent:
	return _event_from_dict(_event_to_dict(event))


static func _events_equal(a: Array[InputEvent], b: Array[InputEvent]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if not _same_input(a[i], b[i]):
			return false
	return true


static func _duplicate_events(events: Array[InputEvent]) -> Array[InputEvent]:
	var duplicated: Array[InputEvent] = []
	for event: InputEvent in events:
		duplicated.append(event.duplicate())
	return duplicated


static func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var pk: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		return {"type": "key", "code": pk}
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return {"type": "mouse", "button": mouse_event.button_index}
	if event is InputEventJoypadButton:
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		return {"type": "joy", "button": joy_event.button_index}
	return {}


static func _event_from_dict(entry: Dictionary) -> InputEvent:
	if not entry.has("type"):
		return null
	match String(entry["type"]):
		"key":
			if not entry.has("code"):
				return null
			return _key_event(int(entry["code"]) as Key)
		"mouse":
			if not entry.has("button"):
				return null
			return _mouse_event(int(entry["button"]) as MouseButton)
		"joy":
			if not entry.has("button"):
				return null
			var event: InputEventJoypadButton = InputEventJoypadButton.new()
			event.button_index = int(entry["button"]) as JoyButton
			return event
	return null
