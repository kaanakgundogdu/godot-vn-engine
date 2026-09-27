class_name VNEngineChapterPreloader
extends RefCounted

var parsed_script: VNEngineStoryScript = null

var script_path: String = ""

var _asset_paths: PackedStringArray = PackedStringArray()

var _requested: bool = false
var _pending: PackedStringArray = PackedStringArray()
var _loaded: Dictionary = {}


func build_plan(script_path_in: String, resolver: VNEngineAssetResolver, flag_list: VNEngineFlagList, chapter: VNEngineChapterDef = null) -> void:
	script_path = script_path_in
	parsed_script = VNEngineScenarioParser.parse_file(script_path, flag_list)

	var cast: VNEngineCast = _load_cast()
	_asset_paths = _collect_asset_paths(parsed_script, resolver, chapter, cast)


func request_all() -> void:
	if _requested:
		return
	_requested = true

	for path in _asset_paths:
		if not ResourceLoader.exists(path):
			continue
		var err: Error = ResourceLoader.load_threaded_request(path, "", true)
		if err != OK:
			VNEngineLog.warn("ChapterPreloader", "load_threaded_request failed (error %d): '%s'" % [err, path])
			continue
		_pending.append(path)


func poll() -> float:
	if _asset_paths.is_empty():
		return 1.0
	if not _requested:
		return 0.0

	var done_count: int = _asset_paths.size() - _pending.size()
	var progress_sum: float = float(done_count)
	var still_pending: PackedStringArray = PackedStringArray()

	for path in _pending:
		var progress_arr: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(path, progress_arr)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_loaded[path] = ResourceLoader.load_threaded_get(path)
				progress_sum += 1.0
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var partial_progress: float = 0.0
				if not progress_arr.is_empty():
					partial_progress = float(progress_arr[0])
				progress_sum += partial_progress
				still_pending.append(path)
			ResourceLoader.THREAD_LOAD_FAILED:
				VNEngineLog.warn("ChapterPreloader", "Load failed (FAILED), skipping: '%s'" % path)
				progress_sum += 1.0
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				VNEngineLog.warn("ChapterPreloader", "Invalid resource (INVALID_RESOURCE), skipping: '%s'" % path)
				progress_sum += 1.0
			_:
				VNEngineLog.warn("ChapterPreloader", "Unknown ResourceLoader status (%d), skipping: '%s'" % [status, path])
				progress_sum += 1.0

	_pending = still_pending
	return progress_sum / float(_asset_paths.size())


func is_done() -> bool:
	if _asset_paths.is_empty():
		return true
	return _requested and _pending.is_empty()


func asset_count() -> int:
	return _asset_paths.size()


func loaded_count() -> int:
	if not _requested:
		return 0
	return _asset_paths.size() - _pending.size()


func _collect_asset_paths(script: VNEngineStoryScript, resolver: VNEngineAssetResolver, chapter: VNEngineChapterDef, cast: VNEngineCast) -> PackedStringArray:
	var seen: Dictionary = {}
	var result: Array[String] = []

	if chapter != null:
		if chapter.intro_background != "":
			_add_path(result, seen, resolver.resolve("background", chapter.intro_background))
		if chapter.bgm != "":
			_add_path(result, seen, resolver.resolve("music", chapter.bgm))

	for node: VNEngineStoryNode in script.nodes:
		for cmd: Dictionary in node.commands:
			var cname: String = cmd.get("name", "")
			var args: String = cmd.get("args", "")
			match cname:
				"bg":
					_add_path(result, seen, resolver.resolve("background", _first_token(args)))
				"cg":
					_add_path(result, seen, resolver.resolve("cg", _first_token(args)))
				"music":
					var music_id: String = args.strip_edges()
					if music_id != "" and music_id.to_lower() != "stop":
						_add_path(result, seen, resolver.resolve("music", music_id))
				"sfx":
					var sfx_id: String = args.strip_edges()
					if sfx_id != "" and sfx_id.to_lower() != "stop":
						_add_path(result, seen, resolver.resolve("sfx", sfx_id))
				"movie":
					var movie_id: String = args.strip_edges()
					if movie_id != "":
						_add_path(result, seen, resolver.resolve("movie", movie_id))
				"eyecatch":
					var asset_id: String = _first_token(args)
					if asset_id != "":
						var path: String = resolver.resolve("cg", asset_id)
						if path == "":
							path = resolver.resolve("background", asset_id)
						_add_path(result, seen, path)
				"show":
					_add_path(result, seen, _resolve_show(args, resolver, cast))

	return PackedStringArray(result)


func _resolve_show(args: String, resolver: VNEngineAssetResolver, cast: VNEngineCast) -> String:
	var parsed: Dictionary = VNEngineCmdShow.parse_show_args(args)
	if parsed.is_empty():
		return ""

	var id: String = parsed["id"]
	var expression: String = parsed["expression"]
	var outfit: String = parsed["outfit"]
	var pose: String = parsed["pose"]
	var shot: String = parsed["shot"]

	var entry: VNEngineCastMember = cast.get_entry(id) if cast != null else null
	if expression == "" and entry != null:
		expression = entry.default_expression
	if outfit == "" and entry != null:
		outfit = entry.default_outfit
	if pose == "" and entry != null:
		pose = entry.default_pose
	if shot == "" and entry != null:
		shot = entry.default_shot

	return resolver.resolve_character(id, outfit, pose, expression, shot)


func _first_token(args: String) -> String:
	var tokens: PackedStringArray = args.strip_edges().split(" ", false)
	return tokens[0] if not tokens.is_empty() else ""


func _add_path(result: Array[String], seen: Dictionary, path: String) -> void:
	if path == "" or seen.has(path):
		return
	seen[path] = true
	result.append(path)


func _load_cast() -> VNEngineCast:
	var db_path: String = VNEnginePaths.cast_file()
	if not ResourceLoader.exists(db_path):
		return null
	return load(db_path) as VNEngineCast
