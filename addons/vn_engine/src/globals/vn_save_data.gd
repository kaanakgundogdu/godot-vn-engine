class_name VNEngineSaveData
extends RefCounted

signal global_changed

enum SlotStatus {EMPTY, OK, CORRUPT}

const QUICKSAVE_SLOT := 99
const AUTOSAVE_SLOT := 98

var global_data: Dictionary = {
	"seen_lines": {},
	"unlocked_cgs": {},
	"endings_seen": {},
	"movies_seen": {},
	"bgm_heard": {},
	"flags": {},
	"total_playtime_sec": 0,
	"cleared_count": 0,
	"first_clear_at": 0,
}

var is_dirty: bool = false

var _save_dir: String = ""


func _init(dir: String) -> void:
	_save_dir = dir if dir.ends_with("/") else dir + "/"
	DirAccess.make_dir_recursive_absolute(_save_dir)
	_load_global_data()


func get_save_dir() -> String:
	return _save_dir


func slot_path(slot_id: int) -> String:
	return get_save_dir() + "save_slot_" + str(slot_id) + ".json"


func thumbnail_path(slot_id: int) -> String:
	return get_save_dir() + "save_slot_" + str(slot_id) + ".png"


func flush() -> void:
	if is_dirty:
		_save_global_data()
		is_dirty = false


func mark_line_seen(chapter_id: String, line_id: String) -> void:
	if not global_data["seen_lines"].has(chapter_id):
		global_data["seen_lines"][chapter_id] = {}

	var seen: Dictionary = global_data["seen_lines"][chapter_id]
	if not seen.has(line_id):
		seen[line_id] = true
		is_dirty = true
		global_changed.emit()


func is_line_seen(chapter_id: String, line_id: String) -> bool:
	if global_data["seen_lines"].has(chapter_id):
		var seen: Dictionary = global_data["seen_lines"][chapter_id]
		return seen.has(line_id)
	return false


func unlock_cg(cg_name: String) -> void:
	if not global_data.has("unlocked_cgs"):
		global_data["unlocked_cgs"] = {}

	if not global_data["unlocked_cgs"].has(cg_name):
		global_data["unlocked_cgs"][cg_name] = true
		is_dirty = true
		global_changed.emit()


func set_global_flag(id: String, value: Variant) -> void:
	global_data["flags"][id.to_lower()] = value
	is_dirty = true
	global_changed.emit()


func mark_ending_seen(id: String) -> void:
	var key: String = id.to_lower()
	if not global_data["endings_seen"].has(key):
		global_data["endings_seen"][key] = int(Time.get_unix_time_from_system())
		is_dirty = true
		global_changed.emit()


func unlock_music(id: String) -> void:
	var key: String = id.to_lower()
	if not global_data["bgm_heard"].has(key):
		global_data["bgm_heard"][key] = int(Time.get_unix_time_from_system())
		is_dirty = true
		global_changed.emit()


func unlock_movie(id: String) -> void:
	var key: String = id.to_lower()
	if not global_data["movies_seen"].has(key):
		global_data["movies_seen"][key] = int(Time.get_unix_time_from_system())
		is_dirty = true
		global_changed.emit()


func is_music_unlocked(id: String) -> bool:
	return global_data["bgm_heard"].has(id.to_lower())


func is_movie_unlocked(id: String) -> bool:
	return global_data["movies_seen"].has(id.to_lower())


func is_ending_seen(id: String) -> bool:
	return global_data["endings_seen"].has(id.to_lower())


func increment_cleared_count() -> void:
	global_data["cleared_count"] = int(global_data.get("cleared_count", 0)) + 1
	is_dirty = true
	global_changed.emit()


static func read_json_dict(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return null

	var data: Variant = json.get_data()
	if not (data is Dictionary):
		return null
	return data


func _global_data_path() -> String:
	return get_save_dir() + "global_data.json"


func _save_global_data() -> void:
	var file: FileAccess = FileAccess.open(_global_data_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(global_data, "\t"))
		file.close()


func _load_global_data() -> void:
	var path: String = _global_data_path()
	if not FileAccess.file_exists(path):
		return

	var raw: Variant = read_json_dict(path)
	if raw == null:
		var corrupt_path: String = get_save_dir() + "global_data.corrupt-%d.json.bak" % int(Time.get_unix_time_from_system())
		var dir: DirAccess = DirAccess.open("user://")
		if dir != null:
			dir.rename(path, corrupt_path)
		VNEngineLog.error("VNEngineSaveData", "global_data.json could not be parsed, renamed to '%s', continuing with defaults" % corrupt_path)
		return

	global_data = _fill_global_defaults(raw)


func _fill_global_defaults(raw: Dictionary) -> Dictionary:
	for key in global_data.keys():
		if not raw.has(key):
			raw[key] = global_data[key]
	return raw
