class_name VNEngineSpeech
extends Node

signal spoken(text: String)

const PROJECT_SETTING := "audio/general/text_to_speech"

static var _bbcode: RegEx = RegEx.create_from_string("\\[(?!lb\\]|rb\\])[^\\]]*\\]")
static var _spaces: RegEx = RegEx.create_from_string("\\s+")

var _voice: String = ""


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if (node is BaseButton or node is Range) and VNEngineMain.instance() != null and VNEngineMain.instance().is_ancestor_of(node):
		(node as Control).mouse_entered.connect(_on_focus_changed.bind(node))


func available() -> bool:
	if not ProjectSettings.get_setting(PROJECT_SETTING, false):
		return false
	return _voice_id() != ""


func enabled() -> bool:
	var settings: VNEngineSettings = VNEngineMain.settings()
	return settings != null and settings.tts


func speak(text: String, interrupt: bool = false) -> void:
	if not enabled():
		return
	var plain: String = plain_text(text)
	if plain == "":
		return
	spoken.emit(plain)
	if not available():
		return
	var settings: VNEngineSettings = VNEngineMain.settings()
	var volume: int = roundi(clampf(settings.master_volume, 0.0, 1.0) * 100.0)
	DisplayServer.tts_speak(plain, _voice_id(), volume, 1.0, settings.tts_rate, 0, interrupt)


func stop() -> void:
	if enabled() and available():
		DisplayServer.tts_stop()


func is_speaking() -> bool:
	return enabled() and available() and DisplayServer.tts_is_speaking()


func toggle() -> void:
	var settings: VNEngineSettings = VNEngineMain.settings()
	if settings == null:
		return
	if settings.tts:
		stop()
	settings.tts = not settings.tts
	settings.save_to_disk()
	settings.changed.emit()
	speak("Text to speech on", true)


static func plain_text(text: String) -> String:
	var plain: String = _bbcode.sub(VNEngineTextMarkup.strip(text), "", true)
	plain = plain.replace("[lb]", "[").replace("[rb]", "]")
	return _spaces.sub(plain, " ", true).strip_edges()


func _voice_id() -> String:
	if _voice != "":
		return _voice
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language(OS.get_locale_language())
	if voices.is_empty():
		voices = PackedStringArray(DisplayServer.tts_get_voices().map(func(v: Dictionary) -> String: return String(v.get("id", ""))))
	if not voices.is_empty():
		_voice = voices[0]
	return _voice


func _on_focus_changed(control: Control) -> void:
	if control == null or not enabled():
		return
	var text: String = describe(control)
	if text != "":
		speak(text, true)


static func describe(control: Control) -> String:
	if control is CheckButton or control is CheckBox:
		return _with_row_label(control, "on" if (control as BaseButton).button_pressed else "off")
	if control is OptionButton:
		return _with_row_label(control, (control as OptionButton).text)
	if control is Range:
		return _with_row_label(control, _range_value(control as Range))
	if control is Button:
		var button := control as Button
		var text: String = button.text
		if text == "":
			for child in button.find_children("*", "", true, false):
				if child is RichTextLabel or child is Label:
					text = child.get_parsed_text() if child is RichTextLabel else (child as Label).text
					break
		if text != "" and button.disabled:
			return "Locked: " + text
		return text
	return ""


static func _with_row_label(control: Control, value: String) -> String:
	var row_label: String = ""
	for sibling in control.get_parent().get_children():
		if sibling is Label and sibling.visible:
			row_label = (sibling as Label).text
			break
	return value if row_label == "" else "%s, %s" % [row_label, value]


static func _range_value(range_control: Range) -> String:
	var labels: Array[Node] = range_control.get_parent().get_children().filter(func(n: Node) -> bool: return n is Label and n.get_index() > range_control.get_index())
	if not labels.is_empty():
		return (labels[0] as Label).text
	return "%d%%" % roundi(range_control.ratio * 100.0)
