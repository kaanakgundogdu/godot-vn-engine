class_name VNEngineSettingsPanel
extends ColorRect

signal closed

const _PREVIEW_SENTENCE: String = "The quick brown fox jumps over the lazy dog."


var _window_size_choices: Array[Vector2i] = []
var _preview_tween: Tween

var _draft: VNEngineSettings

@onready var close_settings_btn: Button = %CloseSettingsButton
@onready var reset_defaults_btn: Button = %ResetDefaultsButton
@onready var settings_tabs: TabContainer = %SettingsTabs

@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var window_size_option: OptionButton = %WindowSizeOption
@onready var vsync_toggle: CheckButton = %VsyncToggle

@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var master_volume_label: Label = %MasterVolumeLabel
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var music_volume_label: Label = %MusicVolumeLabel
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var sfx_volume_label: Label = %SfxVolumeLabel
@onready var voice_volume_slider: HSlider = %VoiceVolumeSlider
@onready var voice_volume_label: Label = %VoiceVolumeLabel
@onready var mute_on_focus_loss_toggle: CheckButton = %MuteOnFocusLossToggle

@onready var text_speed_slider: HSlider = %TextSpeedSlider
@onready var text_speed_preview: RichTextLabel = %TextSpeedPreview
@onready var auto_speed_slider: HSlider = %AutoSpeedSlider
@onready var skip_unread_toggle: CheckButton = %SkipUnreadToggle
@onready var dialog_opacity_slider: HSlider = %DialogOpacitySlider
@onready var dialog_opacity_label: Label = %DialogOpacityLabel
@onready var autosave_toggle: CheckButton = %AutosaveToggle

var controls_page: VNEngineControlsPage


func _ready() -> void:
	close_settings_btn.pressed.connect(_on_close_pressed)
	reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)

	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	window_size_option.item_selected.connect(_on_window_size_selected)
	vsync_toggle.toggled.connect(_on_vsync_toggled)

	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	mute_on_focus_loss_toggle.toggled.connect(_on_mute_on_focus_loss_toggled)

	text_speed_slider.value_changed.connect(_on_text_speed_changed)
	auto_speed_slider.value_changed.connect(_on_auto_speed_changed)
	skip_unread_toggle.toggled.connect(_on_skip_unread_toggled)
	dialog_opacity_slider.value_changed.connect(_on_dialog_opacity_changed)
	autosave_toggle.toggled.connect(_on_autosave_toggled)

	controls_page = VNEngineControlsPage.new()
	controls_page.name = "Controls"
	settings_tabs.add_child(controls_page)


func open_panel() -> void:
	_draft = VNEngineSettings.make_draft()
	show()
	_refresh_controls()
	controls_page.refresh()
	fullscreen_toggle.grab_focus()


func handle_back() -> bool:
	if controls_page != null and controls_page.is_capturing():
		controls_page.cancel_capture()
		return true
	_commit_and_close()
	return true


func _on_close_pressed() -> void:
	_commit_and_close()


func _commit_and_close() -> void:
	_draft.input_overrides = VNEngineInput.export_overrides()
	VNEngineSettings.commit(_draft)
	closed.emit()


func _on_reset_defaults_pressed() -> void:
	if controls_page.is_capturing():
		controls_page.cancel_capture()
	_draft = VNEngineSettings.new()
	VNEngineInput.reset_all()
	_refresh_controls()
	controls_page.refresh()
	_draft.apply_audio()


func _refresh_controls() -> void:
	fullscreen_toggle.set_pressed_no_signal(_draft.fullscreen)
	vsync_toggle.set_pressed_no_signal(_draft.vsync)
	_refresh_window_size_option()
	window_size_option.disabled = _draft.fullscreen

	master_volume_slider.set_value_no_signal(_draft.master_volume)
	master_volume_label.text = _format_percent(_draft.master_volume)
	music_volume_slider.set_value_no_signal(_draft.music_volume)
	music_volume_label.text = _format_percent(_draft.music_volume)
	sfx_volume_slider.set_value_no_signal(_draft.sfx_volume)
	sfx_volume_label.text = _format_percent(_draft.sfx_volume)
	voice_volume_slider.set_value_no_signal(_draft.voice_volume)
	voice_volume_label.text = _format_percent(_draft.voice_volume)
	mute_on_focus_loss_toggle.set_pressed_no_signal(_draft.mute_on_focus_loss)

	text_speed_slider.set_value_no_signal(_draft.text_speed_normalized)
	auto_speed_slider.set_value_no_signal(_draft.auto_speed_normalized)
	skip_unread_toggle.set_pressed_no_signal(_draft.skip_unread)
	dialog_opacity_slider.set_value_no_signal(_draft.window_opacity)
	dialog_opacity_label.text = _format_percent(_draft.window_opacity)
	autosave_toggle.set_pressed_no_signal(_draft.autosave)

	_play_text_speed_preview()


func _refresh_window_size_option() -> void:
	window_size_option.clear()
	var current: Vector2i = _draft.effective_window_size()
	_window_size_choices = VNEngineSettings.WINDOW_SIZES.duplicate()
	var custom_first: bool = not _window_size_choices.has(current)
	if custom_first:
		_window_size_choices.insert(0, current)

	for i: int in _window_size_choices.size():
		var size: Vector2i = _window_size_choices[i]
		var label: String = "%d x %d" % [size.x, size.y]
		if custom_first and i == 0:
			label = "Custom (%s)" % label
		window_size_option.add_item(label)

	window_size_option.select(_window_size_choices.find(current))


func _play_text_speed_preview() -> void:
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()

	text_speed_preview.text = _PREVIEW_SENTENCE
	text_speed_preview.visible_characters = 0
	var total_chars: int = text_speed_preview.get_parsed_text().length()
	var duration: float = maxf(total_chars * _draft.text_speed, 0.01)

	_preview_tween = create_tween()
	_preview_tween.tween_property(text_speed_preview, "visible_characters", total_chars, duration)


func _format_percent(value: float) -> String:
	return "%d%%" % int(round(clampf(value, 0.0, 1.0) * 100.0))


func _on_fullscreen_toggled(button_pressed: bool) -> void:
	_draft.fullscreen = button_pressed
	_draft.display_customized = true
	window_size_option.disabled = button_pressed


func _on_window_size_selected(index: int) -> void:
	if index < 0 or index >= _window_size_choices.size():
		return
	_draft.window_size = _window_size_choices[index]
	_draft.display_customized = true


func _on_vsync_toggled(button_pressed: bool) -> void:
	_draft.vsync = button_pressed
	_draft.display_customized = true


func _on_master_volume_changed(value: float) -> void:
	_draft.master_volume = value
	master_volume_label.text = _format_percent(value)
	_draft.apply_audio()


func _on_music_volume_changed(value: float) -> void:
	_draft.music_volume = value
	music_volume_label.text = _format_percent(value)
	_draft.apply_audio()


func _on_sfx_volume_changed(value: float) -> void:
	_draft.sfx_volume = value
	sfx_volume_label.text = _format_percent(value)
	_draft.apply_audio()


func _on_voice_volume_changed(value: float) -> void:
	_draft.voice_volume = value
	voice_volume_label.text = _format_percent(value)
	_draft.apply_audio()


func _on_mute_on_focus_loss_toggled(button_pressed: bool) -> void:
	_draft.mute_on_focus_loss = button_pressed


func _on_text_speed_changed(value: float) -> void:
	_draft.text_speed_normalized = value
	_play_text_speed_preview()


func _on_auto_speed_changed(value: float) -> void:
	_draft.auto_speed_normalized = value


func _on_skip_unread_toggled(button_pressed: bool) -> void:
	_draft.skip_unread = button_pressed


func _on_dialog_opacity_changed(value: float) -> void:
	_draft.window_opacity = value
	dialog_opacity_label.text = _format_percent(value)


func _on_autosave_toggled(button_pressed: bool) -> void:
	_draft.autosave = button_pressed
