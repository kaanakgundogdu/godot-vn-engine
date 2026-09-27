class_name VNEngineGalleryPanel
extends ColorRect

signal closed

const CARD_SIZE: Vector2 = Vector2(384, 216)
const LOCKED_CARD_COLOR: Color = Color(0.08, 0.08, 0.1, 1.0)
const LOCK_LABEL_FONT_SIZE: int = 58
const BLUR_LOCK_BADGE_FONT_SIZE: int = 28

const CARD_RADIUS: int = 14
const CARD_INSET: float = 8.0
const CARD_BORDER: Color = Color(1.0, 1.0, 1.0, 0.1)
const CARD_BORDER_HOVER: Color = Color(0.45, 0.8, 1.0, 0.5)
const CARD_BG: Color = Color(0.08, 0.08, 0.12, 0.6)

var _asset_resolver: VNEngineAssetResolver
var _extras_def: VNEngineExtrasDef = null
var _locked_blur_shader: Shader = preload("res://addons/vn_engine/src/shaders/locked_blur.gdshader")

var _warned_locked_image: bool = false

@onready var close_btn: Button = %CloseGalleryButton
@onready var grid_container: GridContainer = %GalleryGrid
@onready var full_image_rect: TextureRect = %FullImageRect
@onready var close_full_image_btn: Button = %CloseFullImageButton
@onready var full_image_layer: ColorRect = %FullImageLayer
@onready var gallery_scroll: ScrollContainer = %GalleryScrollContainer
@onready var empty_label: Label = %EmptyLabel
@onready var counter_label: Label = %CounterLabel


func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	close_full_image_btn.pressed.connect(_on_close_full_image_pressed)

	full_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_image_layer.gui_input.connect(_on_full_image_gui_input)

	full_image_layer.hide()


func set_asset_resolver(resolver: VNEngineAssetResolver) -> void:
	_asset_resolver = resolver


func set_extras_def(def: VNEngineExtrasDef) -> void:
	_extras_def = def


func open_panel() -> void:
	show()
	close_btn.grab_focus()

	if _extras_def == null:
		var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
		_extras_def = manifest.get_extras() if manifest != null else VNEngineExtrasDef.new()

	_populate_gallery()


func handle_back() -> bool:
	if full_image_layer.visible:
		_on_close_full_image_pressed()
		return true
	return false


func _on_close_pressed() -> void:
	full_image_layer.hide()
	hide()
	closed.emit()


func _on_full_image_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		_on_close_full_image_pressed()


func _build_entries() -> Array[VNEngineExtrasItem]:
	var result: Array[VNEngineExtrasItem] = []
	var configured: Array[VNEngineExtrasItem] = _extras_def.gallery_items

	if not configured.is_empty():
		for item: VNEngineExtrasItem in configured:
			if item == null or item.id == "":
				continue
			if _asset_resolver.resolve("cg", item.id) == "":
				continue
			result.append(item)
		return result

	for id: String in _asset_resolver.list_all("cg"):
		var default_item: VNEngineExtrasItem = VNEngineExtrasItem.new()
		default_item.id = id
		result.append(default_item)
	return result


func _populate_gallery() -> void:
	_clear_grid()

	var unlocked_cgs: Dictionary = VNEngineMain.save_data().global_data.get("unlocked_cgs", {})
	var entries: Array[VNEngineExtrasItem] = _build_entries()

	if entries.is_empty():
		_show_empty_state(true)
		counter_label.text = "0 / 0"
		return

	_show_empty_state(false)

	var unlocked_count := 0
	for item: VNEngineExtrasItem in entries:
		var is_unlocked: bool = unlocked_cgs.has(item.id)
		if is_unlocked:
			unlocked_count += 1

		if item.hidden_until_unlocked and not is_unlocked:
			continue

		var path: String = _asset_resolver.resolve("cg", item.id)
		if path == "":
			continue

		_create_gallery_button(item, path, is_unlocked)

	counter_label.text = "%d / %d" % [unlocked_count, entries.size()]


func _show_empty_state(is_empty: bool) -> void:
	empty_label.visible = is_empty
	gallery_scroll.visible = not is_empty


func _create_gallery_button(item: VNEngineExtrasItem, cg_path: String, is_unlocked: bool) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.clip_contents = true
	var inset: MarginContainer = _apply_card_frame(btn, CARD_BORDER)

	if is_unlocked:
		var thumb_path: String = item.thumbnail if item.thumbnail != "" else cg_path
		var thumb_tex: Texture2D = load(thumb_path) as Texture2D
		if thumb_tex == null:
			thumb_tex = load(cg_path) as Texture2D

		var tex_rect := TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture = thumb_tex
		inset.add_child(tex_rect)

		var full_tex: Texture2D = load(cg_path) as Texture2D
		btn.pressed.connect(_on_cg_pressed.bind(full_tex))
	else:
		_build_locked_card(btn, item, cg_path, inset)

	grid_container.add_child(btn)


func _build_locked_card(btn: Button, item: VNEngineExtrasItem, cg_path: String, inset: MarginContainer) -> void:
	var style: String = item.locked_style if item.locked_style != "default" else _extras_def.locked_style
	match style:
		"blur":
			_build_blur_lock_card(btn, item, cg_path, inset)
		"image":
			_build_image_lock_card(btn, item, inset)
		_:
			_build_placeholder_lock_card(btn, item, inset)


func _build_placeholder_lock_card(btn: Button, item: VNEngineExtrasItem, inset: MarginContainer) -> void:
	btn.disabled = true

	var lock_bg := ColorRect.new()
	lock_bg.color = LOCKED_CARD_COLOR
	lock_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.add_child(lock_bg)

	var lock_label := Label.new()
	lock_label.text = item.locked_text if item.locked_text != "" else _extras_def.locked_text
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_label.add_theme_font_size_override("font_size", LOCK_LABEL_FONT_SIZE)
	inset.add_child(lock_label)


func _build_blur_lock_card(btn: Button, item: VNEngineExtrasItem, cg_path: String, inset: MarginContainer) -> void:
	var source_path: String = item.thumbnail if item.thumbnail != "" else cg_path
	var tex: Texture2D = load(source_path) as Texture2D
	if tex == null:
		_build_placeholder_lock_card(btn, item, inset)
		return

	btn.disabled = true

	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.texture = tex

	var mat := ShaderMaterial.new()
	mat.shader = _locked_blur_shader
	mat.set_shader_parameter("strength", _extras_def.blur_strength)
	tex_rect.material = mat
	inset.add_child(tex_rect)

	var lock_badge := Label.new()
	lock_badge.text = "Locked"
	lock_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_badge.anchor_left = 0.0
	lock_badge.anchor_right = 1.0
	lock_badge.anchor_top = 1.0
	lock_badge.anchor_bottom = 1.0
	lock_badge.offset_top = -40.0
	lock_badge.add_theme_font_size_override("font_size", BLUR_LOCK_BADGE_FONT_SIZE)
	lock_badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	lock_badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lock_badge.add_theme_constant_override("shadow_offset_x", 1)
	lock_badge.add_theme_constant_override("shadow_offset_y", 1)
	inset.add_child(lock_badge)


func _build_image_lock_card(btn: Button, item: VNEngineExtrasItem, inset: MarginContainer) -> void:
	var locked_image_path: String = _extras_def.locked_image
	var tex: Texture2D = null
	if locked_image_path != "" and ResourceLoader.exists(locked_image_path):
		tex = load(locked_image_path) as Texture2D

	if tex == null:
		if locked_image_path != "" and not _warned_locked_image:
			_warned_locked_image = true
			VNEngineLog.warn("GalleryPanel", "ExtrasDef.locked_image '%s' not found or failed to load, falling back to placeholder style" % locked_image_path)
		_build_placeholder_lock_card(btn, item, inset)
		return

	btn.disabled = true

	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.texture = tex
	inset.add_child(tex_rect)


func _apply_card_frame(btn: Button, border: Color) -> MarginContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(CARD_RADIUS)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = CARD_BG
	sb_hover.border_color = CARD_BORDER_HOVER
	sb_hover.set_border_width_all(1)
	sb_hover.set_corner_radius_all(CARD_RADIUS)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_hover)

	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.add_theme_constant_override("margin_left", int(CARD_INSET))
	inset.add_theme_constant_override("margin_top", int(CARD_INSET))
	inset.add_theme_constant_override("margin_right", int(CARD_INSET))
	inset.add_theme_constant_override("margin_bottom", int(CARD_INSET))
	btn.add_child(inset)
	return inset


func _clear_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()


func _on_cg_pressed(tex: Texture2D) -> void:
	full_image_rect.texture = tex
	full_image_layer.show()
	close_full_image_btn.grab_focus()


func _on_close_full_image_pressed() -> void:
	full_image_rect.texture = null
	full_image_layer.hide()
	close_btn.grab_focus()
