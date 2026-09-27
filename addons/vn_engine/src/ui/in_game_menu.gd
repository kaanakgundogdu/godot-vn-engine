class_name VNEngineInGameButtons
extends HBoxContainer

signal log_requested
signal save_menu_requested
signal load_menu_requested
signal settings_requested
signal menu_requested

const NORMAL_FONT_COLOR: Color = Color(0.8, 0.8, 0.85, 0.75)
const AUTO_ACTIVE_COLOR: Color = Color(0.45, 0.8, 1.0)
const SKIP_ACTIVE_COLOR: Color = Color(1.0, 0.7, 0.3)
const PULSE_ALPHA: float = 0.55
const PULSE_DURATION: float = 1.2

@export var runner: VNEngineStoryRunner

@onready var auto_btn: Button = $AutoMargin/Button
@onready var skip_btn: Button = $SkipMargin/Button
@onready var settings_btn: Button = $SettingsMargin/Button
@onready var log_btn: Button = $LogMargin/Button
@onready var save_btn: Button = $SaveMargin/Button
@onready var load_btn: Button = $LoadMargin/Button
@onready var menu_btn: Button = $MenuMargin/Button

var _auto_tween: Tween
var _skip_tween: Tween


func _ready() -> void:
	hide()

	auto_btn.toggled.connect(_on_auto_toggled)
	skip_btn.pressed.connect(_on_skip_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	log_btn.pressed.connect(_on_log_pressed)
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

	if runner:
		runner.mode_changed.connect(_on_mode_changed)
		runner.dialog_started.connect(_on_dialog_started)
		runner.story_ended.connect(_on_story_ended)


func _on_auto_toggled(toggled_on: bool) -> void:
	if runner:
		runner.is_auto = toggled_on
		if toggled_on:
			runner.is_skip = false
		runner.mode_changed.emit()


func _on_skip_pressed() -> void:
	if runner:
		runner.is_skip = !runner.is_skip
		runner.is_auto = false
		runner.mode_changed.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_log_pressed() -> void:
	log_requested.emit()


func _on_save_pressed() -> void:
	save_menu_requested.emit()


func _on_load_pressed() -> void:
	load_menu_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()


func _on_mode_changed() -> void:
	if runner:
		auto_btn.set_pressed_no_signal(runner.is_auto)
		skip_btn.set_pressed_no_signal(runner.is_skip)
		_auto_tween = _apply_active_style(auto_btn, runner.is_auto, AUTO_ACTIVE_COLOR, _auto_tween)
		_skip_tween = _apply_active_style(skip_btn, runner.is_skip, SKIP_ACTIVE_COLOR, _skip_tween)


func _apply_active_style(btn: Button, active: bool, color: Color, tween: Tween) -> Tween:
	if active:
		_set_button_font_color(btn, color)
		if tween != null and tween.is_valid():
			return tween
		btn.modulate.a = 1.0
		var new_tween: Tween = create_tween().set_loops()
		new_tween.tween_property(btn, "modulate:a", PULSE_ALPHA, PULSE_DURATION)
		new_tween.tween_property(btn, "modulate:a", 1.0, PULSE_DURATION)
		return new_tween

	if tween != null and tween.is_valid():
		tween.kill()
	btn.modulate.a = 1.0
	_set_button_font_color(btn, NORMAL_FONT_COLOR)
	return null


func _set_button_font_color(btn: Button, color: Color) -> void:
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_color_override("font_hover_pressed_color", color)
	btn.add_theme_color_override("font_focus_color", color)


func _on_dialog_started(_node: VNEngineStoryNode) -> void:
	show()


func _on_story_ended() -> void:
	hide()
