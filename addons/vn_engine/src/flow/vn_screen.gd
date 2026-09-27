class_name VNEngineScreen
extends Control

signal finished(result: Dictionary)


func screen_id() -> StringName:
	return &""


func enter(params: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func on_focus() -> void:
	pass


func on_blur() -> void:
	pass


func allows_overlay(id: StringName) -> bool:
	return true


func handle_back() -> bool:
	return false


func handle_alt_click() -> bool:
	return false
