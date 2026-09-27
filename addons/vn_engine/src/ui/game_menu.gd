class_name VNEngineGameMenu
extends ColorRect

signal closed
signal save_requested
signal load_requested
signal settings_requested
signal title_requested
signal quit_requested

@onready var resume_btn: Button = %ResumeButton
@onready var save_btn: Button = %SaveButton
@onready var load_btn: Button = %LoadButton
@onready var settings_btn: Button = %SettingsButton
@onready var title_btn: Button = %TitleButton
@onready var quit_btn: Button = %QuitButton


func _ready() -> void:
	resume_btn.pressed.connect(func() -> void: closed.emit())
	save_btn.pressed.connect(func() -> void: save_requested.emit())
	load_btn.pressed.connect(func() -> void: load_requested.emit())
	settings_btn.pressed.connect(func() -> void: settings_requested.emit())
	title_btn.pressed.connect(func() -> void: title_requested.emit())
	quit_btn.pressed.connect(func() -> void: quit_requested.emit())

	if OS.has_feature("web"):
		quit_btn.hide()


func open_panel() -> void:
	show()
	resume_btn.grab_focus()
