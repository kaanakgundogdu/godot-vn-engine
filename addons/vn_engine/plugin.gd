@tool
extends EditorPlugin

const VNEngineExportPluginScript := preload("res://addons/vn_engine/src/editor/vn_export_plugin.gd")
const TRANSLATIONS_MENU := "VN Engine: Update translations"

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = VNEngineExportPluginScript.new()
	add_export_plugin(_export_plugin)
	add_tool_menu_item(TRANSLATIONS_MENU, _update_translations)


func _exit_tree() -> void:
	remove_tool_menu_item(TRANSLATIONS_MENU)
	remove_export_plugin(_export_plugin)
	_export_plugin = null


func _update_translations() -> void:
	for report in VNEngineTranslationBuilder.build_all():
		if report.has("error"):
			push_warning("VN Engine: %s: %s" % [report["root"], report["error"]])
			continue
		for code: String in report["languages"]:
			var counts: Dictionary = report["languages"][code]
			if counts.has("error"):
				push_warning("VN Engine: " + counts["error"])
				continue
			print("VN Engine: %s  %d translated, %d missing, %d changed, %d unused" % [counts["path"], counts["translated"], counts["missing"], counts["changed"], counts["unused"]])
	EditorInterface.get_resource_filesystem().scan()
