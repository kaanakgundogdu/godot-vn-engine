class_name VNEngineSaveToast
extends Control

const ICON_SIZE: float = 28.0
const MARGIN: float = 32.0
const ICON_SECONDS: float = 0.8
const TEXT_SECONDS: float = 1.5
const FADE_SECONDS: float = 0.2

var _label: Label
var _icon_visible: bool = false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -(MARGIN + 160.0)
	offset_top = MARGIN
	offset_right = -MARGIN
	offset_bottom = MARGIN + ICON_SIZE
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	modulate.a = 0.0
	_label = Label.new()
	_label.text = "Saved"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.visible = false
	add_child(_label)


func on_saved(slot_id: int) -> void:
	var game: VNEngineGame = VNEngineMain.game()
	if game == null or not game.get_ui().save_notice:
		return
	var save_data: VNEngineSaveData = VNEngineMain.save_data()
	var is_auto: bool = save_data != null and save_data.is_autosave_slot(slot_id)
	_show_notice(is_auto)


func _show_notice(is_auto: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_icon_visible = is_auto
	_label.visible = not is_auto
	queue_redraw()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(ICON_SECONDS if is_auto else TEXT_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)


func _draw() -> void:
	if not _icon_visible:
		return
	var origin := Vector2(size.x - ICON_SIZE, size.y - ICON_SIZE)
	var body := Rect2(origin, Vector2(ICON_SIZE, ICON_SIZE))
	draw_rect(body, Color.WHITE, false, 2.0)
	var shutter := Rect2(origin + Vector2(7.0, 2.0), Vector2(14.0, 8.0))
	draw_rect(shutter, Color.WHITE)
	var sticker := Rect2(origin + Vector2(5.0, 15.0), Vector2(18.0, 10.0))
	draw_rect(sticker, Color.WHITE, false, 2.0)
