class_name VNEngineLocale
extends RefCounted

const ENGINE_DIR := "res://addons/vn_engine/translations/"
const FOLDER := "translations/"
const UI_ID := "ui"
const NAME_ID := "language"
const STATUS_COLUMN := "status"

static var source: String = "en"
static var _language: String = "en"
static var _tables: Dictionary = {}
static var _engine_tables: Dictionary = {}
static var _names: Dictionary = {}
static var _translations: Array[Translation] = []


static func load_all(content_root: String, source_language: String) -> void:
	for translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	_tables.clear()
	_engine_tables.clear()
	_names.clear()
	source = source_language if source_language != "" else "en"
	_language = source

	_read_dir(ENGINE_DIR, _engine_tables, false)
	_read_dir(content_root + FOLDER, _tables, true)
	for dir in external_dirs():
		_read_dir(dir, _tables, true)
	_tables.erase(source)

	for code: String in _tables:
		var translation := Translation.new()
		translation.locale = code
		var ui_rows: Dictionary = _engine_tables.get(code, {}).get(UI_ID, {}).duplicate()
		ui_rows.merge(_tables[code].get(UI_ID, {}), true)
		for key: String in ui_rows:
			translation.add_message(key, ui_rows[key])
		TranslationServer.add_translation(translation)
		_translations.append(translation)


static func external_dirs() -> PackedStringArray:
	var dirs := PackedStringArray()
	if not OS.has_feature("editor"):
		dirs.append(OS.get_executable_path().get_base_dir().path_join("translations") + "/")
	dirs.append("user://translations/")
	return dirs


static func languages() -> PackedStringArray:
	var result := PackedStringArray([source])
	var codes: Array = _tables.keys()
	codes.sort()
	result.append_array(PackedStringArray(codes))
	return result


static func language_name(code: String) -> String:
	if _names.has(code):
		return _names[code]
	var name: String = TranslationServer.get_locale_name(code)
	return name if name != "" else code


static func current() -> String:
	return _language


static func resolve(code: String) -> String:
	var available: PackedStringArray = languages()
	if code != "":
		return code if available.has(code) else source
	var os_locale: String = OS.get_locale()
	if available.has(os_locale):
		return os_locale
	if available.has(OS.get_locale_language()):
		return OS.get_locale_language()
	return source


static func apply(code: String) -> void:
	_language = resolve(code)
	if TranslationServer.get_locale() != _language:
		TranslationServer.set_locale(_language)


static func text(key: String, source_text: String) -> String:
	if key == "" or _language == source:
		return source_text
	var value: String = _tables.get(_language, {}).get(key, "")
	return value if value != "" else source_text


static func ui(source_text: String) -> String:
	return String(TranslationServer.translate(source_text))


static func args(entry: Dictionary) -> String:
	var raw: String = entry.get("args", "")
	var key: String = entry.get("key", "")
	if key == "" or _language == source:
		return raw
	var parts: PackedStringArray = raw.split("\"")
	var token: int = 1
	for i in range(1, parts.size(), 2):
		var token_key: String = key if token == 1 else "%s.%d" % [key, token]
		parts[i] = text(token_key, parts[i]).replace("\"", "'")
		token += 1
	return "\"".join(parts)


static func read_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var header: PackedStringArray = _clean(file.get_csv_line())
	if header.size() < 3:
		return {}
	var code: String = header[2] if header[2] != "" else path.get_file().get_basename()
	var rows: Dictionary = {}
	var ui_rows: Dictionary = {}
	while not file.eof_reached():
		var cells: PackedStringArray = _clean(file.get_csv_line())
		if cells.size() < 3 or cells[0] == "":
			continue
		if cells[0] == NAME_ID:
			rows[NAME_ID] = cells[2]
		elif cells[0] == UI_ID:
			if cells[1] != "" and cells[2] != "":
				ui_rows[cells[1]] = cells[2]
		elif cells[2] != "":
			rows[cells[0]] = cells[2]
	rows[UI_ID] = ui_rows
	return {"code": code, "rows": rows}


static func _read_dir(dir_path: String, into: Dictionary, named: bool) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "csv":
			continue
		var data: Dictionary = read_file(dir_path.path_join(file_name))
		if data.is_empty():
			VNEngineLog.warn("Locale", "Skipped '%s': expected a header like 'id,en,ja'" % dir_path.path_join(file_name))
			continue
		var code: String = data["code"]
		var rows: Dictionary = data["rows"]
		if not into.has(code):
			into[code] = {UI_ID: {}}
		var table: Dictionary = into[code]
		table[UI_ID].merge(rows[UI_ID], true)
		rows.erase(UI_ID)
		table.merge(rows, true)
		if named and table.has(NAME_ID):
			_names[code] = table[NAME_ID]


static func _clean(cells: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for cell in cells:
		result.append(cell.replace("\r", "").trim_prefix("﻿"))
	return result
