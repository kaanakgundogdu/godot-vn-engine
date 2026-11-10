class_name VNEngineReadProgress
extends RefCounted

static var _root: String = ""
static var _lines: Dictionary = {}


static func lines() -> Dictionary:
	var root: String = VNEnginePaths.scenario_root()
	if root == _root:
		return _lines
	_root = root
	_lines = {}
	var flag_list: VNEngineFlagList = VNEngineMain.game().get_flag_list()
	for path: String in _scenario_files(root):
		var script: VNEngineStoryScript = VNEngineScenarioLoader.load_script(path, flag_list)
		if script == null:
			continue
		var ids: Dictionary = _lines.get_or_add(script.chapter_id, {})
		for node: VNEngineStoryNode in script.nodes:
			if node.line_index > 0:
				ids[node.line_id] = true
	return _lines


static func total() -> int:
	var count: int = 0
	for ids: Dictionary in lines().values():
		count += ids.size()
	return count


static func read(save_data: VNEngineSaveData) -> int:
	var seen_lines: Dictionary = save_data.global_data.get("seen_lines", {})
	var all_lines: Dictionary = lines()
	var count: int = 0
	for chapter_id: String in all_lines:
		var seen: Dictionary = seen_lines.get(chapter_id, {})
		for line_id: String in all_lines[chapter_id]:
			if seen.has(line_id):
				count += 1
	return count


static func _scenario_files(root: String) -> PackedStringArray:
	var found: Dictionary = {}
	_walk(root, found)
	var paths: PackedStringArray = PackedStringArray(found.keys())
	paths.sort()
	return paths


static func _walk(path: String, found: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_walk(path.path_join(sub), found)
	for file: String in dir.get_files():
		if file.ends_with(".txt"):
			found[path.path_join(file)] = true
		elif file.ends_with(".txt.res"):
			found[path.path_join(file.trim_suffix(".res"))] = true
