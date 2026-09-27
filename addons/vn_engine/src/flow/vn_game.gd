extends Node
class_name VNEngineGame

enum AppState { BOOT, TITLE, CHAPTER, ENDING, CREDITS }

signal returned_to_title
signal quit_requested

var manifest: VNEngineGameManifest = null

var _state: AppState = AppState.BOOT

var _shared_asset_resolver: VNEngineAssetResolver

var _diagnostics_reported: Dictionary = {}

var _diagnostics_logged: Dictionary = {}

var _ending_player: VNEngineEndingPlayer

var _chapter_cache: VNEngineChapterPreloader = null

var pending_load_slot: int = -1


func _ready() -> void:
	_ending_player = VNEngineEndingPlayer.new()


func start_engine() -> void:
	VNEngineInput.register_defaults()
	_apply_content_root(VNEnginePaths.content_root())


func _apply_content_root(path: String) -> void:
	var root: String = path.strip_edges()
	if not root.ends_with("/"):
		root += "/"
	VNEnginePaths.set_content_root(root)

	_shared_asset_resolver = VNEngineAssetResolver.new()
	_chapter_cache = null
	_diagnostics_reported.clear()
	_diagnostics_logged.clear()
	manifest = null

	var asset_map_path: String = VNEnginePaths.asset_map()
	if ResourceLoader.exists(asset_map_path):
		var asset_map: VNEngineAssetMap = load(asset_map_path) as VNEngineAssetMap
		if asset_map == null:
			VNEngineLog.warn("Game", "Asset map failed to load: '%s'" % asset_map_path)
		else:
			_shared_asset_resolver.load_map(asset_map)

	_load_manifest()


func should_report_diagnostics(source: String) -> bool:
	var key: String = source if source != "" else "(unknown source)"
	if _diagnostics_reported.has(key):
		return false
	_diagnostics_reported[key] = true
	return true


func should_log_diagnostics(source: String) -> bool:
	var key: String = source if source != "" else "(unknown source)"
	if _diagnostics_logged.has(key):
		return false
	_diagnostics_logged[key] = true
	return true


func get_shared_asset_resolver() -> VNEngineAssetResolver:
	return _shared_asset_resolver


func get_manifest() -> VNEngineGameManifest:
	return manifest


func get_ui() -> VNEngineUiDef:
	return manifest.get_ui() if manifest != null else VNEngineUiDef.new()


func start_screen() -> StringName:
	if manifest != null and manifest.has_boot_sequence():
		return &"opening"
	return &"title"


func get_flag_list() -> VNEngineFlagList:
	if manifest == null:
		return null
	return manifest.flags


func state() -> int:
	return _state


func take_preparsed_script(script_path: String) -> VNEngineStoryScript:
	if _chapter_cache == null:
		return null
	if _chapter_cache.script_path != script_path:
		return null
	if _chapter_cache.parsed_script == null:
		return null

	var result: VNEngineStoryScript = _chapter_cache.parsed_script
	_chapter_cache.parsed_script = null
	return result


func start_new_game() -> void:
	if not _has_main():
		return
	pending_load_slot = -1
	if manifest == null:
		show_error("start_new_game", "Game manifest not loaded (missing game.tres)")
		return
	if manifest.first_chapter == "":
		show_error("start_new_game", "Manifest has no first_chapter configured")
		return
	goto_chapter(manifest.first_chapter)


func load_slot(slot_id: int) -> void:
	if not _has_main():
		return
	pending_load_slot = slot_id
	var root: VNEngineMain = _vn_main()
	_set_state(AppState.CHAPTER)

	var ui: VNEngineUiDef = get_ui()
	var stage_path: String = root.screen_stack.scene_path(&"stage")

	var slot_chapter: VNEngineChapterDef = _slot_chapter(slot_id)
	if slot_chapter != null:
		_chapter_cache = VNEngineChapterPreloader.new()
		_chapter_cache.build_plan(slot_chapter.script_path, _shared_asset_resolver, get_flag_list(), slot_chapter)
		_chapter_cache.request_all()

	if ui.loading_mode == "never" or stage_path == "" or not root.screen_stack.has_screen(&"loading"):
		root.screen_stack.replace_screen(&"stage", {})
		return

	var loading_params: Dictionary = {
		"paths": PackedStringArray([stage_path]),
		"next_screen": &"stage",
		"next_params": {},
		"mode": ui.loading_mode,
	}
	if _chapter_cache != null:
		loading_params["preloader"] = _chapter_cache
	if ui.loading_mode == "always":
		loading_params["min_duration"] = ui.loading_min_duration
	if ui.loading_show_chapter_title:
		var title: String = _slot_chapter_title(slot_id)
		if title != "":
			loading_params["title"] = title

	root.screen_stack.replace_screen(&"loading", loading_params)


func _slot_chapter(slot_id: int) -> VNEngineChapterDef:
	if manifest == null:
		return null
	var path: String = VNEngineMain.save_data().slot_path(slot_id)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return null
	var meta: Dictionary = (parsed as Dictionary).get("meta", {})
	var chapter_id: String = String(meta.get("chapter_id", ""))
	if chapter_id == "":
		return null

	return manifest.find_chapter(chapter_id)


func _slot_chapter_title(slot_id: int) -> String:
	var chapter: VNEngineChapterDef = _slot_chapter(slot_id)
	if chapter == null:
		return ""
	return _chapter_title(chapter)


func goto_chapter(chapter_id: String) -> void:
	if not _has_main():
		return
	if manifest == null:
		VNEngineLog.warn("Game", "goto_chapter('%s'): manifest not loaded" % chapter_id)
		return

	var chapter: VNEngineChapterDef = manifest.find_chapter(chapter_id)
	if chapter == null:
		show_error("goto_chapter", "Chapter not found: '%s'" % chapter_id)
		return

	var resume_state: Dictionary = {}
	var stage: VNEngineStageScreen = _current_stage_screen()
	if stage != null:
		resume_state = stage.story_runner.state.to_dict(true)

	pending_load_slot = -1
	call_deferred("_enter_chapter_via_loading", chapter, resume_state)
	_set_state(AppState.CHAPTER)


func return_to_title() -> void:
	if not _has_main():
		return
	VNEngineMain.save_data().flush()
	var root: VNEngineMain = _vn_main()
	root.overlay_stack.close_all()
	root.screen_stack.clear_stack()
	root.screen_stack.replace_screen(&"title")
	_set_state(AppState.TITLE)
	returned_to_title.emit()


func quit_game() -> void:
	if quit_requested.get_connections().is_empty():
		get_tree().quit()
	else:
		quit_requested.emit()


func on_story_ended(reason: int, ending_id: String, state: VNEngineStoryState) -> void:
	match reason:
		VNEngineStoryRunner.EndReason.EXPLICIT_END:
			if ending_id != "":
				trigger_ending(ending_id)
			else:
				var chosen: VNEngineEndingDef = _first_matching_ending(state)
				if chosen != null:
					trigger_ending(chosen.id)
				else:
					trigger_ending(manifest.default_ending if manifest != null else "")
		VNEngineStoryRunner.EndReason.SCRIPT_EXHAUSTED:
			finish_chapter(state)
		VNEngineStoryRunner.EndReason.RUNAWAY_GUARD:
			var msg: String = "Runaway guard triggered at node '%s' in '%s', possible infinite loop" % [state.current_node_id, state.current_file]
			VNEngineLog.error("Game", msg)
			show_error(state.current_file, msg)
		_:
			VNEngineLog.error("Game", "on_story_ended(): unknown end_reason: %d" % reason)


func finish_chapter(state: VNEngineStoryState) -> void:
	VNEngineMain.save_data().flush()
	if manifest == null:
		VNEngineLog.warn("Game", "finish_chapter(): no manifest loaded")
		return_to_title()
		return

	var chapter: VNEngineChapterDef = manifest.find_chapter(state.chapter_id)
	if chapter == null:
		VNEngineLog.warn("Game", "finish_chapter(): current chapter not found: '%s', falling back to default_ending" % state.chapter_id)
		trigger_ending(manifest.default_ending)
		return

	for branch in chapter.branches:
		if branch == null:
			continue
		if VNEngineExpressionEvaluator.evaluate(branch.condition, state.flags):
			goto_chapter(branch.chapter_id)
			return

	if chapter.next_chapter != "":
		goto_chapter(chapter.next_chapter)
		return

	trigger_ending(manifest.default_ending)


func trigger_ending(ending_id: String) -> void:
	if not _has_main():
		return
	if ending_id == "":
		VNEngineLog.warn("Game", "trigger_ending(): empty ending_id, no ending selected")
		return_to_title()
		return

	if manifest == null:
		VNEngineLog.warn("Game", "trigger_ending('%s'): no manifest loaded" % ending_id)
		return_to_title()
		return

	var ending: VNEngineEndingDef = manifest.find_ending(ending_id)
	if ending == null:
		VNEngineLog.warn("Game", "trigger_ending(): ending not found: '%s'" % ending_id)
		return_to_title()
		return

	_set_state(AppState.ENDING)
	var save_data: VNEngineSaveData = VNEngineMain.save_data()
	save_data.mark_ending_seen(ending.id)
	save_data.increment_cleared_count()
	for unlock_id in ending.unlocks:
		save_data.set_global_flag(unlock_id, true)
	save_data.flush()

	var root: VNEngineMain = _vn_main()
	await _ending_player.present(root, ending, _current_stage_screen(), _shared_asset_resolver)

	if ending.credits_variant == "none":
		return_to_title()
	else:
		play_credits(ending.credits_variant)

	_ending_player.release(root)


func play_credits(_variant: String = "") -> void:
	if not _has_main():
		return
	var root: VNEngineMain = _vn_main()
	root.screen_stack.replace_screen(&"credits", {"variant": _variant})
	_set_state(AppState.CREDITS)


func seed_flags(state: VNEngineStoryState) -> void:
	if manifest == null or manifest.flags == null:
		return
	var seed: Dictionary = manifest.flags.default_vars()
	var globals: Dictionary = VNEngineMain.save_data().global_data.get("flags", {})
	for key in globals.keys():
		seed[key] = globals[key]
	for key in seed.keys():
		if not state.flags.has(key):
			state.flags[key] = seed[key]


func backfill_chapter_id(state: VNEngineStoryState) -> void:
	if state.chapter_id != "":
		return
	if manifest == null:
		return
	for chapter in manifest.chapters:
		if chapter == null:
			continue
		if chapter.script_path == state.current_file:
			state.chapter_id = chapter.id
			return
	state.chapter_id = manifest.first_chapter


func show_error(source: String, message: String) -> void:
	if not _has_main():
		return
	var root: VNEngineMain = _vn_main()
	if not OS.is_debug_build() or not root.screen_stack.has_screen(&"diagnostics"):
		push_error("Game: %s: %s" % [source, message])
		return_to_title()
		return
	var diagnostic: VNEngineParseDiagnostic = VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.ERROR, 0, message)
	root.screen_stack.push_screen(&"diagnostics", {"source": source, "diagnostics": [diagnostic], "exit_to_title": true})


func open_overlay(id: StringName, params: Dictionary = {}) -> Control:
	if not _has_main():
		return null
	var root: VNEngineMain = _vn_main()
	var final_params: Dictionary = params.duplicate()
	if id == &"gallery":
		final_params["asset_resolver"] = _shared_asset_resolver

	return root.overlay_stack.open_overlay(id, final_params)


func close_overlay() -> void:
	if not _has_main():
		return
	_vn_main().overlay_stack.close_overlay()


func _load_manifest() -> void:
	var manifest_path: String = VNEnginePaths.manifest()
	if not ResourceLoader.exists(manifest_path):
		return

	var manifest_res: Resource = load(manifest_path)
	manifest = manifest_res as VNEngineGameManifest
	if manifest == null:
		VNEngineLog.warn("Game", "Manifest failed to load or is not a GameManifest: '%s'" % manifest_path)
		return

	_state = AppState.BOOT if manifest.has_boot_sequence() else AppState.TITLE

	for chapter in manifest.chapters:
		if chapter == null:
			continue
		var expected_id: String = chapter.script_path.get_base_dir().get_file()
		if chapter.id != expected_id:
			VNEngineLog.warn("Game", "Chapter id '%s' does not match its folder name '%s'" % [chapter.id, expected_id])


func _first_matching_ending(state: VNEngineStoryState) -> VNEngineEndingDef:
	if manifest == null:
		return null
	for ending in manifest.endings:
		if ending == null:
			continue
		if ending.condition == "":
			continue
		if VNEngineExpressionEvaluator.evaluate(ending.condition, state.flags):
			return ending
	return null


func _enter_chapter_immediate(chapter: VNEngineChapterDef, resume_state: Dictionary) -> void:
	var root: VNEngineMain = _vn_main()
	root.screen_stack.replace_screen(&"stage", {
		"story_file": chapter.script_path,
		"resume_state": resume_state,
		"chapter_id": chapter.id,
		"chapter_bgm": chapter.bgm,
	})


func _enter_chapter_via_loading(chapter: VNEngineChapterDef, resume_state: Dictionary) -> void:
	var ui: VNEngineUiDef = get_ui()

	_chapter_cache = VNEngineChapterPreloader.new()
	_chapter_cache.build_plan(chapter.script_path, _shared_asset_resolver, get_flag_list(), chapter)
	_chapter_cache.request_all()

	var root: VNEngineMain = _vn_main()
	if ui.loading_mode == "never" or not root.screen_stack.has_screen(&"loading"):
		_enter_chapter_immediate(chapter, resume_state)
		return

	var stage_path: String = root.screen_stack.scene_path(&"stage")
	var preload_paths: PackedStringArray = PackedStringArray()
	if stage_path != "":
		preload_paths.append(stage_path)

	if preload_paths.is_empty():
		_enter_chapter_immediate(chapter, resume_state)
		return

	var loading_params: Dictionary = {
		"paths": preload_paths,
		"next_screen": &"stage",
		"next_params": {
			"story_file": chapter.script_path,
			"resume_state": resume_state,
			"chapter_id": chapter.id,
			"chapter_bgm": chapter.bgm,
		},
		"mode": ui.loading_mode,
		"preloader": _chapter_cache,
	}
	if ui.loading_mode == "always":
		loading_params["min_duration"] = ui.loading_min_duration
	if ui.loading_show_chapter_title and chapter.intro_style == "none":
		loading_params["title"] = _chapter_title(chapter)
		loading_params["subtitle"] = chapter.subtitle
	if chapter.intro_background != "":
		loading_params["background_path"] = _shared_asset_resolver.resolve("background", chapter.intro_background)

	root.screen_stack.replace_screen(&"loading", loading_params)


func _chapter_title(chapter: VNEngineChapterDef) -> String:
	return chapter.title if chapter.title != "" else chapter.id.capitalize()


func _set_state(new_state: AppState) -> void:
	_state = new_state


func _has_main() -> bool:
	if _vn_main() != null:
		return true
	VNEngineLog.error("Game", "vn_main.tscn is not running. Change to it or add it to the scene tree first.")
	return false


func _vn_main() -> VNEngineMain:
	return VNEngineMain.instance()


func _current_stage_screen() -> VNEngineStageScreen:
	if _vn_main() == null:
		return null
	var screen: VNEngineScreen = _vn_main().screen_stack.current_screen()
	if screen is VNEngineStageScreen:
		return screen as VNEngineStageScreen
	return null
