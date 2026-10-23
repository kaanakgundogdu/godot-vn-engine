class_name VNEngineSaveData
extends RefCounted

signal global_changed

enum SlotStatus {EMPTY, OK, CORRUPT}

const QUICKSAVE_SLOT := 99
const AUTOSAVE_FIRST_SLOT := 100
const DEFAULT_AUTOSAVE_SLOTS := 6
const MAX_REGULAR_SLOT := 97

var global_data: Dictionary = {
	"seen_lines": {},
	"chosen_choices": {},
	"unlocked_cgs": {},
	"endings_seen": {},
	"movies_seen": {},
	"bgm_heard": {},
	"flow_reached": {},
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


func mark_choice_chosen(chapter_id: String, line_id: String) -> void:
	if not global_data["chosen_choices"].has(chapter_id):
		global_data["chosen_choices"][chapter_id] = {}

	var chosen: Dictionary = global_data["chosen_choices"][chapter_id]
	if not chosen.has(line_id):
		chosen[line_id] = true
		is_dirty = true
		global_changed.emit()


func is_choice_chosen(chapter_id: String, line_id: String) -> bool:
	if global_data["chosen_choices"].has(chapter_id):
		var chosen: Dictionary = global_data["chosen_choices"][chapter_id]
		return chosen.has(line_id)
	return false


func autosave_slot_ids() -> Array[int]:
	var game: VNEngineGame = VNEngineMain.game()
	var count: int = game.get_ui().autosave_slots if game != null else DEFAULT_AUTOSAVE_SLOTS
	var ids: Array[int] = []
	for i in range(count):
		ids.append(AUTOSAVE_FIRST_SLOT + i)
	return ids


func is_autosave_slot(slot_id: int) -> bool:
	return autosave_slot_ids().has(slot_id)


func next_autosave_slot() -> int:
	var ids: Array[int] = autosave_slot_ids()
	for slot_id in ids:
		if not FileAccess.file_exists(slot_path(slot_id)):
			return slot_id

	var oldest_slot: int = ids[0]
	var oldest_time: int = slot_saved_at(oldest_slot)
	for slot_id in ids:
		var saved_at: int = slot_saved_at(slot_id)
		if saved_at < oldest_time:
			oldest_time = saved_at
			oldest_slot = slot_id
	return oldest_slot


func slot_saved_at(slot_id: int) -> int:
	var path: String = slot_path(slot_id)
	var raw: Variant = read_json_dict(path)
	if raw != null and raw.has("saved_at"):
		return int(raw["saved_at"])
	return FileAccess.get_modified_time(path)


func most_recent_slot() -> int:
	var best_slot: int = -1
	var best_time: int = -1
	for file_name in DirAccess.get_files_at(_save_dir):
		if not (file_name.begins_with("save_slot_") and file_name.ends_with(".json")):
			continue
		var id_text: String = file_name.trim_prefix("save_slot_").trim_suffix(".json")
		if not id_text.is_valid_int():
			continue
		var slot_id: int = id_text.to_int()
		if not _is_known_slot(slot_id):
			continue
		if VNEngineMain.saves().get_slot_status(slot_id) != SlotStatus.OK:
			continue
		var saved_at: int = slot_saved_at(slot_id)
		if saved_at > best_time:
			best_time = saved_at
			best_slot = slot_id
	return best_slot


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


func mark_flow_reached(box_id: String) -> void:
	global_data["flow_reached"][box_id] = int(Time.get_unix_time_from_system())
	is_dirty = true
	global_changed.emit()


func is_flow_reached(box_id: String) -> bool:
	return global_data["flow_reached"].has(box_id)


func flow_snapshot_path(box_id: String) -> String:
	return get_save_dir() + "flow/" + box_id.validate_filename() + ".json"


func write_flow_snapshot(box_id: String, data: Dictionary) -> void:
	var path: String = flow_snapshot_path(box_id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		VNEngineLog.warn("VNEngineSaveData", "Could not write flow snapshot: %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func read_flow_snapshot(box_id: String) -> Dictionary:
	var raw: Variant = read_json_dict(flow_snapshot_path(box_id))
	if raw == null:
		return {}
	return raw


func has_flow_snapshot(box_id: String) -> bool:
	return FileAccess.file_exists(flow_snapshot_path(box_id))


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


func _is_known_slot(slot_id: int) -> bool:
	if slot_id >= 1 and slot_id <= MAX_REGULAR_SLOT:
		return true
	return slot_id == QUICKSAVE_SLOT or is_autosave_slot(slot_id)
