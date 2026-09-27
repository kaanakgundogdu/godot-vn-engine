@tool
extends RefCounted
class_name VNEnginePaths

const DEFAULT_ROOT := ""

static var _root: String = DEFAULT_ROOT

static func set_content_root(path: String) -> void:
	var root: String = path.strip_edges()
	if not root.ends_with("/"):
		root += "/"
	_root = root

static func content_root() -> String:
	return _root

static func config_dir() -> String:
	return content_root() + "config/"

static func manifest() -> String:
	return config_dir() + "game.tres"

static func asset_map() -> String:
	return config_dir() + "asset_map/_asset_map.tres"

static func cast_file() -> String:
	return config_dir() + "characters/_characters.tres"

static func scenario_root() -> String:
	return content_root() + "scenario/"
