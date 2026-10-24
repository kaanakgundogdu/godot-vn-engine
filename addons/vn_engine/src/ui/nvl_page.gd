class_name VNEngineNvlPage
extends Control

const NAME_WIDTH: float = 260.0
const NAME_GAP: float = 28.0
const ENTRY_GAP: float = 10.0
const SPEAKER_GAP: float = 24.0
const CHOICE_ROW_PAD: float = 16.0
const LINE_SEPARATION: int = 6
const PAST_DIM: Color = Color(1.0, 1.0, 1.0, 0.55)
const INDICATOR_GAP: float = 16.0

var dialog: VNEngineDialogUI

var _rows: Array[Control] = []
var _entries: Array[Dictionary] = []
var _heights: Array[float] = []
var _measure_label: RichTextLabel
var _measure_size: int = -1

@onready var backdrop: Panel = $Backdrop
@onready var content: VBoxContainer = $Content
@onready var entry_box: VBoxContainer = $Content/Entries
@onready var choice_margin: MarginContainer = $Content/ChoiceMargin
@onready var choice_box: VBoxContainer = $Content/ChoiceMargin/Choices
@onready var continue_indicator: Label = $ContinueIndicator


func _ready() -> void:
	choice_margin.add_theme_constant_override("margin_left", int(text_column_x()))
	_measure_label = _make_text_label()
	_measure_label.visible = false
	add_child(_measure_label, false, Node.INTERNAL_MODE_BACK)


func _process(_delta: float) -> void:
	if not continue_indicator.visible or _rows.is_empty():
		return
	var row: Control = _rows.back()
	var bottom: float = content.position.y + entry_box.position.y + row.position.y + row.size.y
	continue_indicator.position = Vector2(content.position.x + content.size.x + INDICATOR_GAP, bottom - continue_indicator.size.y)


func add_entry(speaker_id: String, text: String, kind: String) -> RichTextLabel:
	var speaker_name: String = "" if kind == "choice" else _display_name(speaker_id)
	var gap: float = _gap_before(speaker_id, kind)
	for old_row in _rows:
		old_row.modulate = PAST_DIM
	var row := MarginContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("margin_top", int(gap))
	var label: RichTextLabel = _make_text_label()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind == "choice":
		row.add_theme_constant_override("margin_left", int(text_column_x()))
		label.text = "> " + text
		row.modulate = PAST_DIM
		row.add_child(label)
	elif speaker_name == "":
		label.text = text
		row.add_child(label)
	else:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", int(NAME_GAP))
		var name_label := Label.new()
		name_label.text = speaker_name
		name_label.custom_minimum_size.x = NAME_WIDTH
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_color_override("font_color", _name_color(speaker_id))
		VNEngineSettings.apply_text_scale(name_label, get_theme_default_font_size())
		label.text = text
		line.add_child(name_label)
		line.add_child(label)
		row.add_child(line)
	entry_box.add_child(row)
	_rows.append(row)
	_entries.append({"speaker": speaker_id, "text": text, "kind": kind})
	_heights.append(gap + _measure(speaker_name, text, kind))
	return label


func clear() -> void:
	for row in _rows:
		if is_instance_valid(row):
			entry_box.remove_child(row)
			row.queue_free()
	_rows.clear()
	_entries.clear()
	_heights.clear()
	continue_indicator.hide()


func rebuild(source: Array[Dictionary], reserve: float = 0.0) -> Array[Dictionary]:
	clear()
	var start: int = 0
	if content.size.y > 0.0:
		while start < source.size() - 1 and _span_height(source, start) + reserve > content.size.y:
			start += 1
	var kept: Array[Dictionary] = []
	for i in range(start, source.size()):
		var entry: Dictionary = source[i]
		kept.append(entry)
		add_entry(String(entry.get("speaker", "")), String(entry.get("text", "")), String(entry.get("kind", "line")))
	return kept


func fits(speaker_id: String, text: String, reserve: float = 0.0) -> bool:
	if _rows.is_empty() or content.size.y <= 0.0:
		return true
	var needed: float = _gap_before(speaker_id, "line") + _measure(_display_name(speaker_id), text, "line")
	return used_height() + needed + reserve <= content.size.y


func last_label() -> RichTextLabel:
	if _rows.is_empty():
		return null
	return _rows.back().find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel


func choice_container() -> VBoxContainer:
	return choice_box


func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func used_height() -> float:
	var total: float = 0.0
	for height in _heights:
		total += height
	return total


func estimate_choices_height(count: int) -> float:
	if count <= 0:
		return 0.0
	var row_height: float = _measure("", "> M", "choice") + CHOICE_ROW_PAD
	return ENTRY_GAP + row_height * count


func text_column_x() -> float:
	return NAME_WIDTH + NAME_GAP


func set_backdrop_color(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	backdrop.add_theme_stylebox_override("panel", style)


func _measure(speaker_name: String, text: String, kind: String) -> float:
	var font_size: int = VNEngineSettings.scaled_font_size(get_theme_default_font_size())
	if font_size != _measure_size:
		_measure_size = font_size
		VNEngineSettings.apply_text_scale(_measure_label, get_theme_default_font_size())
	var width: float = content.size.x
	if kind == "choice" or speaker_name != "":
		width -= text_column_x()
	_measure_label.size = Vector2(maxf(width, 10.0), _measure_label.size.y)
	_measure_label.text = ("> " + text) if kind == "choice" else text
	return float(_measure_label.get_content_height())


func _gap_before(speaker_id: String, kind: String) -> float:
	if _entries.is_empty():
		return 0.0
	return _gap_after(_entries.back(), speaker_id, kind)


func _span_height(source: Array[Dictionary], start: int) -> float:
	var total: float = 0.0
	for i in range(start, source.size()):
		var entry: Dictionary = source[i]
		var speaker_id: String = String(entry.get("speaker", ""))
		var kind: String = String(entry.get("kind", "line"))
		if i > start:
			total += _gap_after(source[i - 1], speaker_id, kind)
		total += _measure("" if kind == "choice" else _display_name(speaker_id), String(entry.get("text", "")), kind)
	return total


func _gap_after(last: Dictionary, speaker_id: String, kind: String) -> float:
	var same: bool = _group_key(String(last.get("speaker", "")), String(last.get("kind", ""))) == _group_key(speaker_id, kind)
	return ENTRY_GAP if same else SPEAKER_GAP


func _group_key(speaker_id: String, kind: String) -> String:
	if kind == "choice":
		return "\n"
	return speaker_id if _display_name(speaker_id) != "" else ""


func _make_text_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("line_separation", LINE_SEPARATION)
	VNEngineSettings.apply_text_scale(label, get_theme_default_font_size())
	return label


func _display_name(speaker_id: String) -> String:
	if dialog == null:
		return speaker_id
	return dialog.speaker_display_name(speaker_id)


func _name_color(speaker_id: String) -> Color:
	if dialog == null:
		return Color.WHITE
	return dialog.speaker_name_color(speaker_id)
