class_name VNEngineSaveSystem
extends Node

signal saved(slot_id: int)
signal loaded(slot_id: int)


func save_game(state: VNEngineStoryState, slot_id: int) -> bool:
	var data: VNEngineSaveData = VNEngineMain.save_data()
	var save_path: String = data.slot_path(slot_id)
	var image: Image = get_viewport().get_texture().get_image()

	if image != null:
		image.resize(256, 144)
		image.save_png(data.thumbnail_path(slot_id))

	var preview_text: String = ""
	if not state.history.is_empty():
		var last_entry: Dictionary = state.history[state.history.size() - 1]
		var full_text: String = str(last_entry.get("text", ""))
		preview_text = full_text.substr(0, 60)

	var meta: Dictionary = {
		"chapter_id": state.chapter_id,
		"chapter_title": "",
		"preview_text": preview_text,
		"speaker": state.last_speaker,
		"playtime_sec": state.playtime_sec,
		"ending_id": "",
	}

	var save_data: Dictionary = {
		"engine": "vn_engine/0.5",
		"saved_at": int(Time.get_unix_time_from_system()),
		"meta": meta,
		"state": state.to_dict(),
	}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	data.flush()
	saved.emit(slot_id)
	return true


func load_game(slot_id: int) -> Variant:
	var status: VNEngineSaveData.SlotStatus = get_slot_status(slot_id)
	var save_path: String = VNEngineMain.save_data().slot_path(slot_id)

	match status:
		VNEngineSaveData.SlotStatus.EMPTY:
			VNEngineLog.warn("VNEngineSaveSystem", "Save slot is empty: %d" % slot_id)
			return null
		VNEngineSaveData.SlotStatus.CORRUPT:
			VNEngineLog.warn("VNEngineSaveSystem", "Save file could not be parsed: %s" % save_path)
			return null

	var raw: Variant = VNEngineSaveData.read_json_dict(save_path)
	var result: Variant = _extract_state(raw)
	if result != null:
		loaded.emit(slot_id)
	return result


func get_slot_status(slot_id: int) -> VNEngineSaveData.SlotStatus:
	var save_path: String = VNEngineMain.save_data().slot_path(slot_id)
	if not FileAccess.file_exists(save_path):
		return VNEngineSaveData.SlotStatus.EMPTY

	var raw: Variant = VNEngineSaveData.read_json_dict(save_path)
	if raw == null:
		return VNEngineSaveData.SlotStatus.CORRUPT

	var raw_dict: Dictionary = raw
	var state_data: Dictionary = raw_dict.get("state", {})
	if state_data.is_empty():
		return VNEngineSaveData.SlotStatus.CORRUPT

	return VNEngineSaveData.SlotStatus.OK


func get_save_thumbnail(slot_id: int) -> Texture2D:
	var img_path: String = VNEngineMain.save_data().thumbnail_path(slot_id)
	if FileAccess.file_exists(img_path):
		var image: Image = Image.load_from_file(img_path)
		if image != null:
			return ImageTexture.create_from_image(image)
	return null


func flush() -> void:
	VNEngineMain.save_data().flush()


func _extract_state(raw: Dictionary) -> Variant:
	var state_data: Dictionary = raw.get("state", {})
	if state_data.is_empty():
		VNEngineLog.warn("VNEngineSaveSystem", "Save file has no 'state' block")
		return null
	return state_data
