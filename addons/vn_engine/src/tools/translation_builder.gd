@tool
class_name VNEngineTranslationBuilder
extends RefCounted

const ENGINE_SRC := "res://addons/vn_engine/src/"
const SKIPPED_SCENES := ["card_overlay.tscn", "dev_overlay.tscn", "diagnostics_screen.tscn"]
const CHANGED := "changed"
const UNUSED := "unused"
const IMPORT_FILE := "[remap]\n\nimporter=\"keep\"\n"

static var _scene_text: RegEx = RegEx.create_from_string("^(?:text|tooltip_text|placeholder_text) = \"((?:[^\"\\\\]|\\\\.)*)\"$")
static var _code_text: RegEx = RegEx.create_from_string("\\b(?:tr|ui)\\((?:\"((?:[^\"\\\\]|\\\\.)*)\"|'((?:[^'\\\\]|\\\\.)*)')")
static var _words: RegEx = RegEx.create_from_string("[A-Za-z]{2,}")


static func find_content_roots() -> PackedStringArray:
	var roots := PackedStringArray()
	_find_roots("res://", roots)
	roots.sort()
	return roots


static func build_all() -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for root in find_content_roots():
		reports.append(build(root))
	return reports


static func build(content_root: String) -> Dictionary:
	if not content_root.ends_with("/"):
		content_root += "/"
	var manifest: VNEngineGameManifest = load(content_root + "config/game.tres") as VNEngineGameManifest
	if manifest == null:
		return {"root": content_root, "error": "no config/game.tres"}
	var rows: Array[PackedStringArray] = collect(content_root, manifest)
	var report: Dictionary = {"root": content_root, "rows": rows.size(), "languages": {}}
	for code in manifest.languages:
		if code == "" or code == manifest.source_language:
			continue
		var path: String = content_root + VNEngineLocale.FOLDER + code + ".csv"
		report["languages"][code] = write_language(path, code, manifest.source_language, rows)
	return report


static func collect(content_root: String, manifest: VNEngineGameManifest) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var seen: Dictionary = {}
	var add := func(id: String, text: String) -> void:
		if text.strip_edges() == "":
			return
		var key: String = _row_key(id, text)
		if seen.has(key):
			return
		seen[key] = true
		rows.append(PackedStringArray([id, text]))

	var language_name: String = TranslationServer.get_locale_name(manifest.source_language)
	add.call(VNEngineLocale.NAME_ID, language_name if language_name != "" else manifest.source_language)

	for chapter in manifest.chapters:
		if chapter == null:
			continue
		add.call("chapter.%s.title" % chapter.id, chapter.title)
		add.call("chapter.%s.subtitle" % chapter.id, chapter.subtitle)
	for script_path in _scenario_files(content_root + "scenario/"):
		_collect_script(VNEngineScenarioParser.parse_file(script_path, manifest.flags), add)

	var cast: VNEngineCast = load(content_root + "config/characters/_characters.tres") as VNEngineCast if ResourceLoader.exists(content_root + "config/characters/_characters.tres") else null
	if cast != null:
		for member in cast.characters:
			if member != null:
				add.call("cast." + member.id, member.display_name)
	for ending in manifest.endings:
		if ending != null:
			add.call("ending.%s.title" % ending.id, ending.title)
	if manifest.extras != null:
		for list in [manifest.extras.gallery_items, manifest.extras.music_items, manifest.extras.movie_items]:
			for item: VNEngineExtrasItem in list:
				if item != null:
					add.call("extras.%s.title" % item.id, item.title)
					add.call("extras.%s.locked" % item.id, item.locked_text)

	var ui_texts := PackedStringArray()
	if manifest.extras != null:
		ui_texts.append_array([manifest.extras.locked_text, manifest.extras.locked_name_text, manifest.extras.secret_ending_text])
	for credits in _credits(content_root, manifest):
		for section in credits.sections:
			if section != null:
				ui_texts.append(section.role)
	_collect_source_texts(ENGINE_SRC, ui_texts)
	_collect_source_texts(content_root, ui_texts)
	var engine_dir: DirAccess = DirAccess.open(VNEngineLocale.ENGINE_DIR)
	if engine_dir != null:
		for file_name in engine_dir.get_files():
			if file_name.get_extension() == "csv":
				ui_texts.append_array(PackedStringArray(VNEngineLocale.read_file(VNEngineLocale.ENGINE_DIR + file_name).get("rows", {}).get(VNEngineLocale.UI_ID, {}).keys()))
	for text in ui_texts:
		if _words.search(text) != null:
			add.call(VNEngineLocale.UI_ID, text)
	return rows


static func write_language(path: String, code: String, source: String, rows: Array[PackedStringArray]) -> Dictionary:
	var old: Dictionary = _read_existing(path)
	var engine: Dictionary = VNEngineLocale.read_file(VNEngineLocale.ENGINE_DIR + code + ".csv").get("rows", {})
	var engine_ui: Dictionary = engine.get(VNEngineLocale.UI_ID, {})
	var counts: Dictionary = {"translated": 0, "missing": 0, CHANGED: 0, UNUSED: 0}
	var lines := PackedStringArray([_csv_line(["id", source, code, VNEngineLocale.STATUS_COLUMN])])
	var used: Dictionary = {}
	for row in rows:
		var key: String = _row_key(row[0], row[1])
		used[key] = true
		var translated: String = ""
		var status: String = ""
		if old.has(key):
			var previous: PackedStringArray = old[key]
			translated = previous[2]
			status = previous[3] if previous[3] != UNUSED else ""
			if translated != "" and previous[1] != row[1]:
				status = CHANGED
		if translated == "" and row[0] == VNEngineLocale.UI_ID:
			translated = engine_ui.get(row[1], "")
		if status == CHANGED:
			counts[CHANGED] += 1
		counts["translated" if translated != "" else "missing"] += 1
		lines.append(_csv_line([row[0], row[1], translated, status]))
	for key: String in old:
		var previous: PackedStringArray = old[key]
		if used.has(key) or previous[2] == "":
			continue
		counts[UNUSED] += 1
		lines.append(_csv_line([previous[0], previous[1], previous[2], UNUSED]))

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"error": "could not write %s" % path}
	file.store_string("\n".join(lines) + "\n")
	file.close()
	if not FileAccess.file_exists(path + ".import"):
		var import_file: FileAccess = FileAccess.open(path + ".import", FileAccess.WRITE)
		if import_file != null:
			import_file.store_string(IMPORT_FILE)
	counts["path"] = path
	return counts


static func _collect_script(script: VNEngineStoryScript, add: Callable) -> void:
	if script == null:
		return
	for node in script.nodes:
		for cmd in node.commands:
			var cmd_name: String = cmd.get("name", "")
			if cmd_name == "flow":
				add.call("%s.%s.flow" % [script.chapter_id, node.base_id], " ".join(VNEngineCommand.parse_quoted_args(cmd.get("args", ""))))
			elif cmd.has("key"):
				var parts: PackedStringArray = String(cmd.get("args", "")).split("\"")
				var token: int = 1
				for i in range(1, parts.size(), 2):
					add.call(cmd["key"] if token == 1 else "%s.%d" % [cmd["key"], token], parts[i])
					token += 1
		if node.text != "":
			add.call(node.line_id, node.text)
		for choice in node.choices:
			add.call(choice.line_id, choice.text)
			add.call(choice.line_id + ".hint", choice.hint)


static func _collect_source_texts(dir_path: String, into: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub.begins_with(".") or sub == "scenario" or sub == "translations":
			continue
		_collect_source_texts(dir_path.path_join(sub) + "/", into)
	for file_name in dir.get_files():
		var extension: String = file_name.get_extension()
		if extension != "tscn" and extension != "gd":
			continue
		if extension == "tscn" and SKIPPED_SCENES.has(file_name):
			continue
		var file: FileAccess = FileAccess.open(dir_path.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		while not file.eof_reached():
			var line: String = file.get_line()
			if extension == "tscn":
				var found: RegExMatch = _scene_text.search(line)
				if found != null:
					into.append(found.get_string(1).c_unescape())
				continue
			for found in _code_text.search_all(line):
				into.append((found.get_string(1) + found.get_string(2)).c_unescape())


static func _credits(content_root: String, manifest: VNEngineGameManifest) -> Array[VNEngineCreditsDef]:
	var result: Array[VNEngineCreditsDef] = []
	if manifest.credits != null:
		result.append(manifest.credits)
	var dir: DirAccess = DirAccess.open(content_root + "config/credits/")
	if dir == null:
		return result
	for file_name in dir.get_files():
		if file_name.get_extension() != "tres":
			continue
		var credits: VNEngineCreditsDef = load(content_root + "config/credits/" + file_name) as VNEngineCreditsDef
		if credits != null and not result.has(credits):
			result.append(credits)
	return result


static func _scenario_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return files
	var subs: PackedStringArray = dir.get_directories()
	subs.sort()
	for sub in subs:
		files.append_array(_scenario_files(dir_path.path_join(sub) + "/"))
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name in names:
		if file_name.get_extension() == "txt":
			files.append(dir_path.path_join(file_name))
	return files


static func _find_roots(dir_path: String, roots: PackedStringArray) -> void:
	if FileAccess.file_exists(dir_path.path_join("config/game.tres")):
		roots.append(dir_path if dir_path.ends_with("/") else dir_path + "/")
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub.begins_with(".") or FileAccess.file_exists(dir_path.path_join(sub).path_join(".gdignore")):
			continue
		_find_roots(dir_path.path_join(sub), roots)


static func _read_existing(path: String) -> Dictionary:
	var result: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	file.get_csv_line()
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() < 2 or cells[0] == "":
			continue
		while cells.size() < 4:
			cells.append("")
		for i in cells.size():
			cells[i] = cells[i].replace("\r", "")
		result[_row_key(cells[0], cells[1])] = cells
	return result


static func _row_key(id: String, text: String) -> String:
	return "ui:" + text if id == VNEngineLocale.UI_ID else id


static func _csv_line(cells: Array) -> String:
	var out := PackedStringArray()
	for cell in cells:
		var text: String = String(cell)
		if text.contains(",") or text.contains("\"") or text.contains("\n") or text != text.strip_edges():
			text = "\"" + text.replace("\"", "\"\"") + "\""
		out.append(text)
	return ",".join(out)
