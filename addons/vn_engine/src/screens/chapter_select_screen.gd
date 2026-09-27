class_name VNEngineChapterSelectScreen
extends VNEngineScreen


const LOCKED_TEXT: String = "🔒 ???"
const BUTTON_MIN_HEIGHT: float = 72.0
const LOCKED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.5)

const CARD_RADIUS: int = 10
const CARD_BG: Color = Color(0.08, 0.08, 0.12, 0.75)
const CARD_BG_HOVER: Color = Color(0.13, 0.13, 0.19, 0.88)
const CARD_BORDER: Color = Color(1.0, 1.0, 1.0, 0.08)
const CARD_BORDER_HOVER: Color = Color(0.45, 0.8, 1.0, 0.45)
const CARD_BG_LOCKED: Color = Color(0.05, 0.05, 0.07, 0.55)
const CARD_BORDER_LOCKED: Color = Color(1.0, 1.0, 1.0, 0.05)

@onready var chapter_list: VBoxContainer = %ChapterList
@onready var empty_label: Label = %EmptyLabel
@onready var back_button: Button = %BackButton
@onready var debug_label: Label = %DebugLabel


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	debug_label.visible = OS.is_debug_build()


func screen_id() -> StringName:
	return &"chapter_select"


func enter(_params: Dictionary) -> void:
	_populate_chapters()


func handle_back() -> bool:
	VNEngineMain.game().return_to_title()
	return true


func _on_back_pressed() -> void:
	handle_back()


func _populate_chapters() -> void:
	_clear_list()

	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	if manifest == null:
		empty_label.text = "Chapter list unavailable (manifest not found)."
		empty_label.show()
		return

	if manifest.chapters.is_empty():
		empty_label.text = "No chapters defined yet."
		empty_label.show()
		return

	empty_label.hide()

	var flags: Dictionary = VNEngineMain.save_data().global_data.get("flags", {})

	for chapter in manifest.chapters:
		if chapter == null:
			continue
		_create_chapter_button(chapter, flags)


func _clear_list() -> void:
	for child in chapter_list.get_children():
		child.queue_free()


func _is_unlocked(chapter: VNEngineChapterDef, flags: Dictionary) -> bool:
	if OS.is_debug_build():
		return true
	if chapter.unlock_condition == "":
		return true
	return VNEngineExpressionEvaluator.evaluate(chapter.unlock_condition, flags)


func _display_name(chapter: VNEngineChapterDef) -> String:
	if chapter.title == "":
		return chapter.id
	return chapter.title


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(CARD_RADIUS)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	return sb


func _create_chapter_button(chapter: VNEngineChapterDef, flags: Dictionary) -> void:
	var unlocked: bool = _is_unlocked(chapter, flags)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	if unlocked:
		btn.add_theme_stylebox_override("normal", _card_style(CARD_BG, CARD_BORDER))
		btn.add_theme_stylebox_override("hover", _card_style(CARD_BG_HOVER, CARD_BORDER_HOVER))
		btn.add_theme_stylebox_override("pressed", _card_style(CARD_BG_HOVER, CARD_BORDER_HOVER))
		btn.add_theme_stylebox_override("focus", _card_style(CARD_BG_HOVER, CARD_BORDER_HOVER))
	else:
		btn.add_theme_stylebox_override("disabled", _card_style(CARD_BG_LOCKED, CARD_BORDER_LOCKED))

	if unlocked:
		var title: String = _display_name(chapter)
		if chapter.subtitle != "":
			btn.text = "%s\n%s" % [title, chapter.subtitle]
		else:
			btn.text = title
		btn.pressed.connect(_on_chapter_pressed.bind(chapter.id))
	else:
		btn.text = LOCKED_TEXT
		btn.disabled = true
		btn.modulate = LOCKED_MODULATE

	chapter_list.add_child(btn)


func _on_chapter_pressed(chapter_id: String) -> void:
	VNEngineMain.game().goto_chapter(chapter_id)
