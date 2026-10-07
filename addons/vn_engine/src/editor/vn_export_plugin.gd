@tool
extends EditorExportPlugin

const ADDON_ROOT := "res://addons/vn_engine/"
const SAMPLE_GAME_DIR := ADDON_ROOT + "sample_game/"
const DEV_OVERLAY_SCENE := ADDON_ROOT + "src/ui/scenes/dev_overlay.tscn"
const DIAGNOSTICS_SCENE := ADDON_ROOT + "src/screens/scenes/diagnostics_screen.tscn"

const TEMP_SCRIPT_PATH := "user://vn_export_scenario_tmp.res"

var _seen_txt: Dictionary = {}
var _flag_list: VNEngineFlagList = null
var _sample_game_is_run_target: bool = false
var _is_debug: bool = false


func _get_name() -> String:
	return "VNEngineExport"


func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	_seen_txt.clear()
	_flag_list = null
	_is_debug = is_debug
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_sample_game_is_run_target = main_scene.begins_with(SAMPLE_GAME_DIR)


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if not _is_debug and path.begins_with(SAMPLE_GAME_DIR) and not _sample_game_is_run_target:
		skip()
		return

	if path.ends_with(".txt") and _is_scenario_file(path):
		skip()
		return

	if path.ends_with("/config/game.tres"):
		var manifest: VNEngineGameManifest = load(path) as VNEngineGameManifest
		_flag_list = manifest.flags if manifest != null else null
		_add_scenario_files(path.get_base_dir().get_base_dir() + "/scenario/")

	if not _is_debug and (path == DEV_OVERLAY_SCENE or path == DIAGNOSTICS_SCENE):
		skip()


func _is_scenario_file(path: String) -> bool:
	var marker_index: int = path.rfind("/scenario/")
	if marker_index == -1:
		return false
	return FileAccess.file_exists(path.substr(0, marker_index) + "/config/game.tres")


func _add_scenario_files(scenario_root: String) -> void:
	var dir: DirAccess = DirAccess.open(scenario_root)
	if dir == null:
		return
	_walk_scenario_dir(dir, scenario_root)


func _walk_scenario_dir(dir: DirAccess, current_path: String) -> void:
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = current_path + entry
		if dir.current_is_dir():
			var sub_dir: DirAccess = DirAccess.open(full_path)
			if sub_dir != null:
				_walk_scenario_dir(sub_dir, full_path + "/")
		elif entry.ends_with(".txt") and not _seen_txt.has(full_path):
			_seen_txt[full_path] = true
			_bake_scenario(full_path)
		entry = dir.get_next()


func _bake_scenario(path: String) -> void:
	var script: VNEngineStoryScript = VNEngineScenarioParser.parse_file(path, _flag_list)
	var save_error: Error = ResourceSaver.save(script, TEMP_SCRIPT_PATH)
	if save_error != OK:
		push_error("VNEngineExport: could not bake scenario '%s' (error %d)" % [path, save_error])
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(TEMP_SCRIPT_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SCRIPT_PATH))
	if bytes.is_empty():
		push_error("VNEngineExport: baked scenario is empty '%s'" % path)
		return
	add_file(path + ".res", bytes, false)
