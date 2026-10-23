class_name VNEngineLoadPanel
extends ColorRect

signal closed
signal load_requested(slot_id: int)
signal save_requested(slot_id: int)

const SLOTS_PER_PAGE: int = 6
const TOTAL_PAGES: int = 5

enum Category { SAVES, AUTO, QUICK }

const CARD_RADIUS: int = 10
const CARD_BG: Color = Color(0.08, 0.08, 0.12, 0.75)
const CARD_BG_HOVER: Color = Color(0.13, 0.13, 0.19, 0.88)
const CARD_BORDER: Color = Color(1.0, 1.0, 1.0, 0.08)
const CARD_BORDER_HOVER: Color = Color(0.45, 0.8, 1.0, 0.45)
const CARD_BG_DISABLED: Color = Color(0.05, 0.05, 0.07, 0.55)
const CARD_BORDER_DISABLED: Color = Color(1.0, 1.0, 1.0, 0.05)
const MONTHS: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const LOCKED_BADGE_COLOR: Color = Color(1.0, 0.7, 0.3, 0.9)

var current_category: Category = Category.SAVES
var current_page: int = 1
var is_save_mode: bool = false

@onready var close_load_btn: Button = %CloseLoadButton
@onready var saves_category_btn: Button = %SavesCategoryButton
@onready var auto_category_btn: Button = %AutoCategoryButton
@onready var quick_category_btn: Button = %QuickCategoryButton
@onready var slot_grid: GridContainer = %SlotGrid
@onready var pagination_box: HBoxContainer = %PaginationBox


func _ready() -> void:
	close_load_btn.pressed.connect(_on_close_pressed)
	_setup_categories()
	_setup_pagination()


func open_panel(save_mode: bool = false) -> void:
	is_save_mode = save_mode
	show()
	close_load_btn.grab_focus()
	_update_slot_grid()


func _on_close_pressed() -> void:
	hide()
	closed.emit()


func _setup_categories() -> void:
	var selected: StyleBoxFlat = _card_style(CARD_BG_HOVER, CARD_BORDER_HOVER)
	var normal: StyleBox = saves_category_btn.get_theme_stylebox("normal")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		selected.set_content_margin(side, normal.get_content_margin(side))
	var categories: Dictionary = {
		saves_category_btn: Category.SAVES,
		auto_category_btn: Category.AUTO,
		quick_category_btn: Category.QUICK,
	}
	for btn: Button in categories:
		btn.add_theme_stylebox_override("pressed", selected)
		btn.add_theme_stylebox_override("hover_pressed", selected)
		btn.pressed.connect(_on_category_pressed.bind(categories[btn]))


func _on_category_pressed(category: Category) -> void:
	current_category = category
	_update_slot_grid()


func _setup_pagination() -> void:
	for page in range(1, TOTAL_PAGES + 1):
		var page_btn := Button.new()
		page_btn.text = " " + str(page) + " "
		page_btn.pressed.connect(_on_page_button_pressed.bind(page))
		pagination_box.add_child(page_btn)


func _on_page_button_pressed(page_num: int) -> void:
	current_page = page_num
	_update_slot_grid()


func _update_slot_grid() -> void:
	for child in slot_grid.get_children():
		child.queue_free()

	saves_category_btn.set_pressed_no_signal(current_category == Category.SAVES)
	auto_category_btn.set_pressed_no_signal(current_category == Category.AUTO)
	quick_category_btn.set_pressed_no_signal(current_category == Category.QUICK)
	pagination_box.visible = current_category == Category.SAVES

	if current_category == Category.AUTO:
		for slot_id in _auto_slots_newest_first():
			slot_grid.add_child(_build_special_card(slot_id, "Auto Save"))
		return

	if current_category == Category.QUICK:
		slot_grid.add_child(_build_special_card(VNEngineSaveData.QUICKSAVE_SLOT, "Quick Save"))
		return

	var start_slot: int = (current_page - 1) * SLOTS_PER_PAGE + 1
	var end_slot: int = mini(start_slot + SLOTS_PER_PAGE, VNEngineSaveData.MAX_REGULAR_SLOT + 1)

	for slot_id in range(start_slot, end_slot):
		slot_grid.add_child(_build_slot_button(slot_id))


func _auto_slots_newest_first() -> Array[int]:
	var slots: Array[int] = VNEngineMain.save_data().autosave_slot_ids()
	var save_data: VNEngineSaveData = VNEngineMain.save_data()
	slots.sort_custom(func(a: int, b: int) -> bool: return save_data.slot_saved_at(a) > save_data.slot_saved_at(b))
	return slots


func _build_slot_button(slot_id: int) -> Button:
	return _build_card(slot_id, "Save " + str(slot_id))


func _build_special_card(slot_id: int, label: String) -> Button:
	var card: Button = _build_card(slot_id, label)
	if is_save_mode:
		card.disabled = true
		card.modulate = Color(1.0, 1.0, 1.0, 0.55)

		var locked_lbl := Label.new()
		locked_lbl.text = "Locked"
		locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		locked_lbl.theme_type_variation = &"VNSmallLabel"
		locked_lbl.add_theme_color_override("font_color", LOCKED_BADGE_COLOR)
		card.get_child(0).add_child(locked_lbl)
	return card


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(CARD_RADIUS)
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


func _build_card(slot_id: int, display_name: String) -> Button:
	var status: VNEngineSaveData.SlotStatus = VNEngineMain.saves().get_slot_status(slot_id)

	var slot_btn := Button.new()
	slot_btn.custom_minimum_size = Vector2(340, 250)
	slot_btn.add_theme_stylebox_override("normal", _card_style(CARD_BG, CARD_BORDER))
	slot_btn.add_theme_stylebox_override("hover", _card_style(CARD_BG_HOVER, CARD_BORDER_HOVER))
	slot_btn.add_theme_stylebox_override("pressed", _card_style(CARD_BG_HOVER, CARD_BORDER_HOVER))
	slot_btn.add_theme_stylebox_override("focus", _card_style(CARD_BG_HOVER, CARD_BORDER_HOVER))
	slot_btn.add_theme_stylebox_override("disabled", _card_style(CARD_BG_DISABLED, CARD_BORDER_DISABLED))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	slot_btn.add_child(vbox)

	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(256, 144)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tex_rect)

	var lbl := Label.new()
	lbl.theme_type_variation = &"VNSmallLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	match status:
		VNEngineSaveData.SlotStatus.OK:
			lbl.text = "%s · %s" % [display_name, _saved_at_text(slot_id)]
			var thumb: Texture2D = VNEngineMain.saves().get_save_thumbnail(slot_id)
			if thumb:
				tex_rect.texture = thumb
		VNEngineSaveData.SlotStatus.CORRUPT:
			lbl.text = "Corrupted save"
			tex_rect.modulate = Color(0, 0, 0, 0.5)
			slot_btn.disabled = true
		_:
			lbl.text = display_name + " (Empty)"
			tex_rect.modulate = Color(0, 0, 0, 0.5)

	slot_btn.pressed.connect(_on_slot_pressed.bind(slot_id))
	return slot_btn


func _on_slot_pressed(slot_id: int) -> void:
	if is_save_mode:
		_handle_save_slot_pressed(slot_id)
	elif VNEngineMain.saves().get_slot_status(slot_id) == VNEngineSaveData.SlotStatus.OK:
		load_requested.emit(slot_id)


func _handle_save_slot_pressed(slot_id: int) -> void:
	var occupied: bool = VNEngineMain.saves().get_slot_status(slot_id) != VNEngineSaveData.SlotStatus.EMPTY
	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()

	if not (occupied and ui_def.confirm_overwrite_save):
		save_requested.emit(slot_id)
		return

	VNEngineMain.game().open_overlay(&"confirm", {
		"message": "Overwrite this save?",
		"confirm_text": "Overwrite",
		"cancel_text": "Cancel",
	}).confirmed.connect(_on_overwrite_confirmed.bind(slot_id))


func _on_overwrite_confirmed(slot_id: int) -> void:
	save_requested.emit(slot_id)


func _saved_at_text(slot_id: int) -> String:
	var bias_minutes: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(VNEngineMain.save_data().slot_saved_at(slot_id) + bias_minutes * 60)
	return "%d %s %02d:%02d" % [local["day"], MONTHS[int(local["month"]) - 1], local["hour"], local["minute"]]
