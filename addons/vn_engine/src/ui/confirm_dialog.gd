class_name VNEngineConfirmDialog
extends ColorRect

signal confirmed
signal cancelled
signal closed

@onready var message_label: Label = %MessageLabel
@onready var confirm_btn: Button = %ConfirmButton
@onready var cancel_btn: Button = %CancelButton


func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)


func configure(params: Dictionary) -> void:
	message_label.text = String(params.get("message", ""))
	confirm_btn.text = String(params.get("confirm_text", "Yes"))
	cancel_btn.text = String(params.get("cancel_text", "No"))


func open_panel() -> void:
	show()
	cancel_btn.grab_focus()


func handle_back() -> bool:
	_on_cancel_pressed()
	return true


func _on_confirm_pressed() -> void:
	closed.emit()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	closed.emit()
	cancelled.emit()
