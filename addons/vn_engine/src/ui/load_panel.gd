class_name VNEngineLoadPanel
extends ColorRect

signal closed
signal load_requested(slot_id: int)
signal save_requested(slot_id: int)

const SLOTS_PER_PAGE: int = 6
const TOTAL_PAGES: int = 5

const MAX_REGULAR_SLOT: int = 97

const CARD_RADIUS: int = 10
const CARD_BG: Color = Color(0.08, 0.08, 0.12, 0.75)
const CARD_BG_HOVER: Color = Color(0.13, 0.13, 0.19, 0.88)
const CARD_BORDER: Color = Color(1.0, 1.0, 1.0, 0.08)
const CARD_BORDER_HOVER: Color = Color(0.45, 0.8, 1.0, 0.45)
const CARD_BG_DISABLED: Color = Color(0.05, 0.05, 0.07, 0.55)
const CARD_BORDER_DISABLED: Color = Color(1.0, 1.0, 1.0, 0.05)
const LOCKED_BADGE_COLOR: Color = Color(1.0, 0.7, 0.3, 0.9)

var current_page: int = 1
var is_save_mode: bool = false

@onready var actual_load_btn: Button = %ActualLoadButton
@onready var close_load_btn: Button = %CloseLoadButton
@onready var slot_grid: GridContainer = %SlotGrid
@onready var pagination_box: HBoxContainer = %PaginationBox


func _ready() -> void:
	close_load_btn.pressed.connect(_on_close_pressed)
	actual_load_btn.pressed.connect(_on_actual_load_pressed)
	_setup_pagination()


func open_panel(save_mode: bool = false) -> void:
	is_save_mode = save_mode
	show()
	close_load_btn.grab_focus()
	_update_slot_grid()


func _on_close_pressed() -> void:
	hide()
	closed.emit()


func _setup_pagination() -> void:
	for i in range(1, TOTAL_PAGES + 1):
		var page_btn := Button.new()
		page_btn.text = " " + str(i) + " "
		page_btn.pressed.connect(_on_page_button_pressed.bind(i))
		pagination_box.add_child(page_btn)


func _on_page_button_pressed(page_num: int) -> void:
	current_page = page_num
	_update_slot_grid()


func _update_slot_grid() -> void:
	for child in slot_grid.get_children():
		child.queue_free()

	if current_page == 1:
		slot_grid.add_child(_build_special_card(VNEngineSaveData.AUTOSAVE_SLOT, "Autosave"))
		slot_grid.add_child(_build_special_card(VNEngineSaveData.QUICKSAVE_SLOT, "Quicksave"))

	var regular_capacity: int = SLOTS_PER_PAGE - (2 if current_page == 1 else 0)
	var start_slot: int = _regular_slots_before_page(current_page) + 1
	var end_slot: int = mini(start_slot + regular_capacity, MAX_REGULAR_SLOT + 1)

	for slot_id in range(start_slot, end_slot):
		slot_grid.add_child(_build_slot_button(slot_id))


func _regular_slots_before_page(page: int) -> int:
	if page <= 1:
		return 0
	return (SLOTS_PER_PAGE - 2) + (page - 2) * SLOTS_PER_PAGE


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
			lbl.text = display_name + " (Used)"
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


func _on_actual_load_pressed() -> void:
	var slot_id: int = _most_recent_quick_slot()
	if slot_id == -1:
		return
	load_requested.emit(slot_id)


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


func _most_recent_quick_slot() -> int:
	var quick_ok: bool = VNEngineMain.saves().get_slot_status(VNEngineSaveData.QUICKSAVE_SLOT) == VNEngineSaveData.SlotStatus.OK
	var auto_ok: bool = VNEngineMain.saves().get_slot_status(VNEngineSaveData.AUTOSAVE_SLOT) == VNEngineSaveData.SlotStatus.OK

	if quick_ok and auto_ok:
		if _slot_modified_time(VNEngineSaveData.AUTOSAVE_SLOT) > _slot_modified_time(VNEngineSaveData.QUICKSAVE_SLOT):
			return VNEngineSaveData.AUTOSAVE_SLOT
		return VNEngineSaveData.QUICKSAVE_SLOT
	if quick_ok:
		return VNEngineSaveData.QUICKSAVE_SLOT
	if auto_ok:
		return VNEngineSaveData.AUTOSAVE_SLOT
	return -1


func _slot_modified_time(slot_id: int) -> int:
	var path: String = VNEngineMain.save_data().slot_path(slot_id)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary and parsed.has("saved_at"):
			return int(parsed["saved_at"])
	return FileAccess.get_modified_time(path)
