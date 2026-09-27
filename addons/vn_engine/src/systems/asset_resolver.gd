class_name VNEngineAssetResolver
extends RefCounted

var _entries: Dictionary = {}
var _cache: Dictionary = {}
var _warned: Dictionary = {}

var silent: bool = false


func load_map(map: VNEngineAssetMap) -> void:
	_entries.clear()
	_cache.clear()

	if map == null:
		return

	for entry: VNEngineAssetMapEntry in map.entries:
		if entry == null:
			continue
		_entries[entry.kind] = entry


func resolve(kind: String, name: String) -> String:
	var cache_key: String = kind + "|" + name
	if _cache.has(cache_key):
		return _cache[cache_key]

	var entry: VNEngineAssetMapEntry = _entries.get(kind, null)
	if entry == null:
		_warn_once(kind, name, "'%s' (kind=%s) not found: no entry for this kind in asset_map.tres" % [name, kind])
		_cache[cache_key] = ""
		return ""

	var tried: Array[String] = []
	for ext: String in entry.extensions:
		var path: String = entry.root + name + ext
		tried.append(path)
		if ResourceLoader.exists(path):
			_cache[cache_key] = path
			return path

	_warn_once(kind, name, "'%s' (kind=%s) not found, tried paths: %s" % [name, kind, str(tried)])
	_cache[cache_key] = ""
	return ""


func resolve_character(char_id: String, outfit: String, pose: String, expression: String, shot: String) -> String:
	var cache_key: String = "character|%s|%s|%s|%s|%s" % [char_id, outfit, pose, expression, shot]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var entry: VNEngineAssetMapEntry = _entries.get("character", null)
	if entry == null:
		_warn_once("character", char_id, "'%s' (kind=character) not found: no 'character' entry in asset_map.tres" % char_id)
		_cache[cache_key] = ""
		return ""

	var suffix: String = "%s_%s_%s_%s_%s" % [char_id, outfit, pose, expression, shot]
	var tried: Array[String] = []
	for ext: String in entry.extensions:
		var path: String = entry.root + char_id + "/" + suffix + ext
		tried.append(path)
		if ResourceLoader.exists(path):
			_cache[cache_key] = path
			return path

	_warn_once("character", char_id, "'%s' (kind=character) not found, tried paths: %s" % [suffix, str(tried)])
	_cache[cache_key] = ""
	return ""


func exists(kind: String, name: String) -> bool:
	return resolve(kind, name) != ""


func resolve_voice(char_id: String, line_id: String) -> String:
	var name: String = "%s/%s" % [char_id, line_id]
	var cache_key: String = "voice|%s" % name
	if _cache.has(cache_key):
		return _cache[cache_key]

	var entry: VNEngineAssetMapEntry = _entries.get("voice", null)
	if entry == null:
		_cache[cache_key] = ""
		return ""

	for ext: String in entry.extensions:
		var path: String = entry.root + name + ext
		if ResourceLoader.exists(path):
			_cache[cache_key] = path
			return path

	_cache[cache_key] = ""
	return ""


func list_all(kind: String) -> Array[String]:
	var result: Array[String] = []

	var entry: VNEngineAssetMapEntry = _entries.get(kind, null)
	if entry == null:
		_warn_once(kind, "", "list_all: no entry for kind '%s' in asset_map.tres" % kind)
		return result

	var relative_paths: Dictionary = {}
	_scan_dir(entry.root, entry.root, relative_paths)

	var ids: Dictionary = {}
	for rel: String in relative_paths:
		for ext: String in entry.extensions:
			if rel.ends_with(ext):
				ids[rel.substr(0, rel.length() - ext.length())] = true
				break

	result.assign(ids.keys())
	result.sort()
	return result


func _scan_dir(root: String, current_path: String, out: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(current_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path: String = current_path + file_name if current_path.ends_with("/") else current_path + "/" + file_name

		if dir.current_is_dir():
			_scan_dir(root, full_path + "/", out)
		else:
			var stripped_name: String = file_name
			if stripped_name.ends_with(".import"):
				stripped_name = stripped_name.substr(0, stripped_name.length() - 7)
			elif stripped_name.ends_with(".remap"):
				stripped_name = stripped_name.substr(0, stripped_name.length() - 6)
			var stripped_path: String = current_path + stripped_name if current_path.ends_with("/") else current_path + "/" + stripped_name
			out[stripped_path.replace(root, "")] = true

		file_name = dir.get_next()

	dir.list_dir_end()


func _warn_once(kind: String, id: String, message: String) -> void:
	if silent:
		return
	var key: String = kind + "|" + id
	if _warned.has(key):
		return
	_warned[key] = true
	VNEngineLog.warn("AssetResolver", message)
