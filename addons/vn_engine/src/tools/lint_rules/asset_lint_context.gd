@tool
class_name VNEngineAssetLintContext
extends RefCounted


var asset_map: VNEngineAssetMap
var resolver: VNEngineAssetResolver
var cast: VNEngineCast
var manifest: VNEngineGameManifest
var scenario_paths: Array[String] = []
var scripts: Array[VNEngineStoryScript] = []
var refs: Dictionary = {}

var rx_bg: RegEx
var rx_cg: RegEx
var rx_character: RegEx
var rx_music: RegEx
var rx_sfx: RegEx
var rx_ui: RegEx
var rx_movie: RegEx

var _lines: Array[String] = []
var _note: String = ""


func setup() -> bool:
	_compile_patterns()

	asset_map = load(VNEnginePaths.asset_map()) as VNEngineAssetMap
	if asset_map == null:
		VNEngineLog.error("AssetLintContext", "Failed to load %s, cannot lint" % VNEnginePaths.asset_map())
		return false

	resolver = VNEngineAssetResolver.new()
	resolver.silent = true
	resolver.load_map(asset_map)

	cast = load(VNEnginePaths.cast_file()) as VNEngineCast
	if cast == null:
		VNEngineLog.warn("AssetLintContext", "Failed to load %s, character-based rules run with reduced data" % VNEnginePaths.cast_file())

	if ResourceLoader.exists(VNEnginePaths.manifest()):
		manifest = load(VNEnginePaths.manifest()) as VNEngineGameManifest
		if manifest == null:
			VNEngineLog.warn("AssetLintContext", "%s loaded but is not a GameManifest, manifest-based rules are skipped" % VNEnginePaths.manifest())

	scenario_paths = _find_scenario_files(VNEnginePaths.scenario_root())
	for path in scenario_paths:
		scripts.append(VNEngineScenarioParser.parse_file(path))

	refs = _collect_references(scripts, cast)
	return true


func reset_section() -> void:
	_lines.clear()
	_note = ""


func error(message: String) -> void:
	_lines.append("- [ERROR] %s" % message)


func warn(message: String) -> void:
	_lines.append("- [WARNING] %s" % message)


func info(message: String) -> void:
	_note = message


func build_section(section_title: String) -> String:
	var out := "## %s\n\n" % section_title
	if _note != "":
		out += "_%s_\n\n" % _note
	if _lines.is_empty():
		out += "No issues found.\n\n"
	else:
		out += "%d issue(s):\n\n" % _lines.size()
		for line in _lines:
			out += line + "\n"
		out += "\n"
	return out


func walk_files(root: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_walk_files_rec(root, "", out)
	return out


func kind_root_exists(kind: String) -> bool:
	for entry in asset_map.entries:
		if entry != null and entry.kind == kind:
			return true
	return false


func _compile_patterns() -> void:
	rx_bg = RegEx.new()
	rx_bg.compile("^bg_[a-z][a-z0-9]*(_[a-z][a-z0-9]*)*\\.(png|webp)$")

	rx_cg = RegEx.new()
	rx_cg.compile("^cg_[a-z][a-z0-9]*(_[a-z][a-z0-9]*)*_[0-9]{2,}(_[a-z][a-z0-9]*)?\\.(png|webp)$")

	rx_character = RegEx.new()
	rx_character.compile("^[a-z][a-z0-9]*_[a-z][a-z0-9]*_[a-z][a-z0-9]*_[a-z][a-z0-9]*_(far|mid|close)\\.png$")

	rx_music = RegEx.new()
	rx_music.compile("^bgm_[a-z][a-z0-9]*(_[a-z][a-z0-9]*)*\\.ogg$")

	rx_sfx = RegEx.new()
	rx_sfx.compile("^sfx_[a-z][a-z0-9]*_[a-z][a-z0-9]*\\.(wav|ogg)$")

	rx_ui = RegEx.new()
	rx_ui.compile("^ui_[a-z][a-z0-9]*_[a-z][a-z0-9]*(_[a-z][a-z0-9]*)?\\.png$")

	rx_movie = RegEx.new()
	rx_movie.compile("^(op|ed|ev)_[a-z][a-z0-9_]*\\.ogv$")


func _walk_files_rec(root: String, rel_dir: String, out: Array[Dictionary]) -> void:
	var current_path: String = root + rel_dir
	var dir: DirAccess = DirAccess.open(current_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		if dir.current_is_dir():
			_walk_files_rec(root, rel_dir + file_name + "/", out)
		elif not _is_sidecar_file(file_name):
			out.append({
				"basename": file_name,
				"rel_dir": rel_dir,
				"rel_path": rel_dir + file_name,
			})

		file_name = dir.get_next()

	dir.list_dir_end()


func _is_sidecar_file(file_name: String) -> bool:
	return file_name.ends_with(".import") or file_name.ends_with(".uid") or file_name == ".gitkeep"


func _find_scenario_files(root: String) -> Array[String]:
	var out: Array[String] = []
	_find_scenario_files_rec(root, out)
	return out


func _find_scenario_files_rec(path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path: String = path + file_name if path.ends_with("/") else path + "/" + file_name
		if dir.current_is_dir():
			_find_scenario_files_rec(full_path + "/", out)
		elif file_name.ends_with(".txt"):
			out.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


func _collect_references(scanned_scripts: Array[VNEngineStoryScript], cast_db: VNEngineCast) -> Dictionary:
	var out: Dictionary = {
		"background": [],
		"cg": [],
		"music": [],
		"sfx": [],
		"movie": [],
		"character": [],
	}

	for story in scanned_scripts:
		for node in story.nodes:
			for cmd in node.commands:
				var cname: String = cmd.get("name", "")
				var cargs: String = cmd.get("args", "")
				var line_no: int = cmd.get("line", 0)

				match cname:
					"bg":
						var toks: PackedStringArray = cargs.strip_edges().split(" ", false)
						if not toks.is_empty():
							out["background"].append({"name": toks[0], "source": story.source_path, "line": line_no})
					"cg":
						var cg_toks: PackedStringArray = cargs.strip_edges().split(" ", false)
						if not cg_toks.is_empty():
							out["cg"].append({"name": cg_toks[0], "source": story.source_path, "line": line_no})
					"eyecatch":
						var ec_toks: PackedStringArray = cargs.strip_edges().split(" ", false)
						if not ec_toks.is_empty():
							var ec_id: String = ec_toks[0]
							if resolver.exists("background", ec_id) and not resolver.exists("cg", ec_id):
								out["background"].append({"name": ec_id, "source": story.source_path, "line": line_no})
							else:
								out["cg"].append({"name": ec_id, "source": story.source_path, "line": line_no})
					"music":
						var music_name: String = cargs.strip_edges()
						if music_name != "" and music_name.to_lower() != "stop":
							out["music"].append({"name": music_name, "source": story.source_path, "line": line_no})
					"sfx":
						var sfx_name: String = cargs.strip_edges()
						if sfx_name != "" and sfx_name.to_lower() != "stop":
							out["sfx"].append({"name": sfx_name, "source": story.source_path, "line": line_no})
					"movie":
						var movie_name: String = cargs.strip_edges()
						if movie_name != "":
							out["movie"].append({"name": movie_name, "source": story.source_path, "line": line_no})
					"show":
						var parsed: Dictionary = _parse_show_args(cargs, cast_db)
						if parsed.get("char_id", "") != "":
							parsed["source"] = story.source_path
							parsed["line"] = line_no
							out["character"].append(parsed)

	return out


func _parse_show_args(args: String, cast_db: VNEngineCast) -> Dictionary:
	var tokens: PackedStringArray = args.strip_edges().split(" ", false)
	if tokens.is_empty():
		return {}

	var char_id: String = tokens[0].to_lower()
	var expression := ""
	var outfit := ""
	var pose := ""
	var shot := ""

	var i := 1
	if i < tokens.size() and tokens[i] != "at" and tokens[i] != "with" and not tokens[i].contains("="):
		expression = tokens[i]
		i += 1

	while i < tokens.size():
		if tokens[i] == "at" and i + 1 < tokens.size():
			i += 2
		elif tokens[i] == "with" and i + 1 < tokens.size():
			i += 2
		elif tokens[i].begins_with("outfit="):
			outfit = tokens[i].substr(7)
			i += 1
		elif tokens[i].begins_with("pose="):
			pose = tokens[i].substr(5)
			i += 1
		elif tokens[i].begins_with("shot="):
			shot = tokens[i].substr(5)
			i += 1
		else:
			i += 1

	var entry: VNEngineCastMember = null
	if cast_db:
		entry = cast_db.get_entry(char_id)

	if expression == "" and entry:
		expression = entry.default_expression
	if outfit == "" and entry:
		outfit = entry.default_outfit
	if pose == "" and entry:
		pose = entry.default_pose
	if shot == "" and entry:
		shot = entry.default_shot

	return {"char_id": char_id, "outfit": outfit, "pose": pose, "expression": expression, "shot": shot}
