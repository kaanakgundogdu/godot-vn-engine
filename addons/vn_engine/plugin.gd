@tool
extends EditorPlugin

const VNEngineExportPluginScript := preload("res://addons/vn_engine/src/editor/vn_export_plugin.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = VNEngineExportPluginScript.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
