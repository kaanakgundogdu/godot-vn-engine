class_name VNEngineLogUI
extends ColorRect

signal closed

const NARRATOR_DIM := 0.8
const DEFAULT_ACCENT_COLOR := Color(0.85, 0.78, 1.0)
const SEPARATOR_COLOR := Color(1.0, 1.0, 1.0, 0.12)

@export var runner: VNEngineStoryRunner

@onready var close_btn: Button = %CloseLogButton
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var log_container: VBoxContainer = %LogContainer


func _ready() -> void:
	hide()
	close_btn.pressed.connect(_on_close_pressed)

	if runner:
		runner.state_restored.connect(_on_state_restored)


func set_runner(r: VNEngineStoryRunner) -> void:
	if runner == r:
		return
	runner = r
	if runner and not runner.state_restored.is_connected(_on_state_restored):
		runner.state_restored.connect(_on_state_restored)


func open_panel() -> void:
	_rebuild()
	show()
	_scroll_to_bottom.call_deferred()


func close_panel() -> void:
	hide()
	_clear_log()
	closed.emit()


func handle_back() -> bool:
	close_panel()
	return true


func _on_close_pressed() -> void:
	close_panel()


func _clear_log() -> void:
	for child in log_container.get_children():
		child.queue_free()


func _build_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = SEPARATOR_COLOR
	sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sb)
	return sep


func _rebuild() -> void:
	_clear_log()

	if runner == null or runner.state == null:
		return

	var entries: Array[Dictionary] = []
	for entry: Dictionary in runner.state.history:
		if String(entry.get("text", "")) != "":
			entries.append(entry)
	for i in entries.size():
		log_container.add_child(_build_entry(entries[i]))
		if i < entries.size() - 1:
			log_container.add_child(_build_separator())


func _build_entry(entry: Dictionary) -> Control:
	var speaker_id: String = String(entry.get("speaker", ""))
	var line_id: String = String(entry.get("line_id", ""))
	var text_raw: String = String(entry.get("text", ""))

	var is_narrator: bool = true
	var char_entry: VNEngineCastMember = null
	var db: VNEngineCast = _cast()
	if speaker_id != "":
		if db != null:
			is_narrator = db.is_narrator(speaker_id)
			char_entry = db.get_entry(speaker_id)
		else:
			is_narrator = speaker_id.to_lower() == "narrator"

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	if speaker_id != "" and not is_narrator:
		container.add_child(_build_name_row(speaker_id, line_id, char_entry))

	var text_label := RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var display_text: String = text_raw
	if is_narrator or speaker_id == "":
		text_label.text = "[i]%s[/i]" % display_text
		text_label.modulate = Color(1.0, 1.0, 1.0, NARRATOR_DIM)
	else:
		text_label.text = display_text

	container.add_child(text_label)
	return container


func _build_name_row(speaker_id: String, line_id: String, char_entry: VNEngineCastMember) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	var display_name: String = char_entry.display_name if char_entry != null and char_entry.display_name != "" else speaker_id.capitalize().to_upper()
	name_label.text = display_name
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	name_label.add_theme_color_override("font_color", _name_color(char_entry))
	row.add_child(name_label)

	var voice_path: String = _resolve_voice_path(speaker_id, line_id)
	if voice_path != "":
		var play_btn := Button.new()
		play_btn.text = "▶"
		play_btn.tooltip_text = "Play voice"
		play_btn.custom_minimum_size = Vector2(32.0, 32.0)
		play_btn.pressed.connect(_on_play_voice.bind(speaker_id, line_id))
		row.add_child(play_btn)

	return row


func _name_color(char_entry: VNEngineCastMember) -> Color:
	if char_entry != null and _log_use_character_colors():
		return char_entry.name_color
	return DEFAULT_ACCENT_COLOR


func _log_use_character_colors() -> bool:
	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	if manifest == null:
		return true
	return manifest.get_ui().log_use_character_colors


func _cast() -> VNEngineCast:
	if runner == null or runner.ctx == null or runner.ctx.characters == null:
		return null
	return runner.ctx.characters.cast


func _resolve_voice_path(speaker_id: String, line_id: String) -> String:
	if speaker_id == "" or line_id == "":
		return ""
	var db: VNEngineCast = _cast()
	if db == null or db.is_narrator(speaker_id):
		return ""
	if runner.ctx.assets == null:
		return ""

	return runner.ctx.assets.resolve_voice(speaker_id, line_id)


func _on_play_voice(speaker_id: String, line_id: String) -> void:
	if runner == null or runner.ctx == null or runner.ctx.audio == null:
		return

	var voice_file_name: String = "%s/%s" % [speaker_id, line_id]
	runner.ctx.audio.play_channel("voice", voice_file_name, speaker_id)


func _on_state_restored(_state: VNEngineStoryState) -> void:
	if visible:
		_rebuild()


func _scroll_to_bottom() -> void:
	var scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()
	scrollbar.value = scrollbar.max_value
