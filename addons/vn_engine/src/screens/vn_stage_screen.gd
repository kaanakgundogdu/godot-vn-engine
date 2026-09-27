class_name VNEngineStageScreen
extends VNEngineScreen


@onready var story_runner: VNEngineStoryRunner = $StoryRunner
@onready var in_game_buttons: VNEngineInGameButtons = $CanvasLayer/InGameButtons


func _ready() -> void:
	VNEngineMain.instance().persistent_audio.attach_runner(story_runner)

	in_game_buttons.save_menu_requested.connect(_on_save_menu_requested)
	in_game_buttons.load_menu_requested.connect(_on_load_menu_requested)
	in_game_buttons.settings_requested.connect(_on_settings_requested)
	in_game_buttons.log_requested.connect(_on_log_requested)
	in_game_buttons.menu_requested.connect(open_game_menu)

	story_runner.story_ended.connect(_on_story_ended)

	story_runner.state_restored.connect(_on_state_restored)

	story_runner.parse_diagnostics_ready.connect(_on_parse_diagnostics_ready)


func screen_id() -> StringName:
	return &"stage"


func handle_back() -> bool:
	if VNEngineMain.game().state() == VNEngineGame.AppState.CHAPTER:
		open_game_menu()
		return true
	return false


func enter(params: Dictionary) -> void:
	var game: VNEngineGame = VNEngineMain.game()
	story_runner.flag_list = game.get_flag_list()

	if game.pending_load_slot != -1:
		var slot: int = game.pending_load_slot
		game.pending_load_slot = -1
		story_runner.execute_load_game(slot)
	else:
		var file: String = params.get("story_file", "")
		if file == "":
			VNEngineLog.error("VNStageScreen", "enter() called without a 'story_file' parameter")
			return

		var resume_state: Dictionary = params.get("resume_state", {})
		if not resume_state.is_empty():
			story_runner.state.from_dict(resume_state)

		var chapter_id_param: String = params.get("chapter_id", "")
		if chapter_id_param != "":
			story_runner.state.chapter_id = chapter_id_param

		_apply_chapter_bgm(params.get("chapter_bgm", ""))

		if chapter_id_param != "":
			await _maybe_show_chapter_intro(chapter_id_param)

		game.seed_flags(story_runner.state)
		story_runner.start_story(file)
		_autosave_on_chapter_enter(chapter_id_param)


func exit() -> void:
	VNEngineMain.instance().persistent_audio.detach_runner()


func on_blur() -> void:
	if story_runner.is_auto or story_runner.is_skip:
		story_runner.is_auto = false
		story_runner.is_skip = false
		story_runner.mode_changed.emit()


func _on_story_ended() -> void:
	VNEngineMain.game().on_story_ended(story_runner.end_reason, story_runner.end_ending_id, story_runner.state)


func _on_state_restored(state: VNEngineStoryState) -> void:
	var game: VNEngineGame = VNEngineMain.game()
	game.backfill_chapter_id(state)
	game.seed_flags(state)


func _on_parse_diagnostics_ready(diagnostics: Array) -> void:
	var source: String = ""
	if story_runner.script_res != null:
		source = story_runner.script_res.source_path
	var source_name: String = source.get_file() if source != "" else "(unknown source)"

	var game: VNEngineGame = VNEngineMain.game()
	var should_log: bool = game.should_log_diagnostics(source)
	var has_error: bool = false
	for entry in diagnostics:
		var diag: VNEngineParseDiagnostic = entry as VNEngineParseDiagnostic
		if diag == null:
			continue
		if diag.severity == VNEngineParseDiagnostic.Severity.ERROR:
			has_error = true
		if not should_log:
			continue
		match diag.severity:
			VNEngineParseDiagnostic.Severity.ERROR:
				VNEngineLog.error("VNStageScreen", "%s: %s" % [source_name, diag.format()])
			VNEngineParseDiagnostic.Severity.WARNING:
				VNEngineLog.warn("VNStageScreen", "%s: %s" % [source_name, diag.format()])
			_:
				VNEngineLog.debug("VNStageScreen", "%s: %s" % [source_name, diag.format()])

	if not has_error:
		return

	var root: VNEngineMain = VNEngineMain.instance()
	if not OS.is_debug_build() or not root.screen_stack.has_screen(&"diagnostics"):
		if not game.should_report_diagnostics(source):
			return
		game.return_to_title()
		return

	if root.screen_stack.current_id() == &"diagnostics":
		return

	if not game.should_report_diagnostics(source):
		return

	root.screen_stack.push_screen(&"diagnostics", {"diagnostics": diagnostics, "source": source})


func _on_save_menu_requested() -> void:
	_open_load_panel(true)


func _on_load_menu_requested() -> void:
	_open_load_panel(false)


func _on_settings_requested() -> void:
	VNEngineMain.game().open_overlay(&"settings")


func _on_log_requested() -> void:
	VNEngineMain.game().open_overlay(&"log", {"runner": story_runner})


func open_game_menu() -> void:
	var menu: Control = VNEngineMain.game().open_overlay(&"game_menu")
	if menu == null:
		return
	if menu.has_signal("save_requested"):
		menu.save_requested.connect(_on_menu_save)
	if menu.has_signal("load_requested"):
		menu.load_requested.connect(_on_menu_load)
	if menu.has_signal("settings_requested"):
		menu.settings_requested.connect(_on_menu_settings)
	if menu.has_signal("title_requested"):
		menu.title_requested.connect(_on_menu_title)
	if menu.has_signal("quit_requested"):
		menu.quit_requested.connect(_on_menu_quit)


func _on_menu_save() -> void:
	VNEngineMain.game().close_overlay()
	_open_load_panel(true)


func _on_menu_load() -> void:
	VNEngineMain.game().close_overlay()
	_open_load_panel(false)


func _on_menu_settings() -> void:
	var game: VNEngineGame = VNEngineMain.game()
	game.close_overlay()
	game.open_overlay(&"settings")


func _on_menu_title() -> void:
	var game: VNEngineGame = VNEngineMain.game()
	var manifest: VNEngineGameManifest = game.get_manifest()
	var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()
	if not ui_def.confirm_return_to_title:
		game.return_to_title()
		return

	game.open_overlay(&"confirm", {
		"message": "Return to the title screen? Unsaved progress will be lost.",
		"confirm_text": "Title",
		"cancel_text": "Cancel",
	}).confirmed.connect(game.return_to_title)


func _on_menu_quit() -> void:
	var game: VNEngineGame = VNEngineMain.game()
	var manifest: VNEngineGameManifest = game.get_manifest()
	var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()
	if not ui_def.confirm_quit:
		game.quit_game()
		return

	game.open_overlay(&"confirm", {
		"message": "Quit the game?",
		"confirm_text": "Quit",
		"cancel_text": "Cancel",
	}).confirmed.connect(game.quit_game)


func _open_load_panel(save_mode: bool) -> void:
	var panel: Control = VNEngineMain.game().open_overlay(&"load", {"save_mode": save_mode})
	panel.load_requested.connect(_on_load_slot_requested)
	panel.save_requested.connect(_on_save_slot_requested)


func _on_load_slot_requested(slot_id: int) -> void:
	VNEngineMain.game().close_overlay()
	story_runner.execute_load_game(slot_id)


func _on_save_slot_requested(slot_id: int) -> void:
	VNEngineMain.game().close_overlay()

	await get_tree().process_frame
	await get_tree().process_frame

	VNEngineMain.saves().save_game(story_runner.state, slot_id)
	_open_load_panel(true)


func _apply_chapter_bgm(bgm_id: String) -> void:
	if bgm_id == "":
		return
	story_runner.state.audio["music"] = bgm_id
	if story_runner.ctx.audio:
		story_runner.ctx.audio.play_channel("music", bgm_id)


func _autosave_on_chapter_enter(chapter_id: String) -> void:
	if chapter_id == "":
		return

	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	var chapter: VNEngineChapterDef = manifest.find_chapter(chapter_id) if manifest != null else null
	if chapter == null:
		return

	if not chapter.autosave_on_enter:
		return
	if not VNEngineMain.settings().autosave:
		return

	await get_tree().process_frame
	await get_tree().process_frame
	VNEngineMain.saves().save_game(story_runner.state, VNEngineSaveData.AUTOSAVE_SLOT)


func _maybe_show_chapter_intro(chapter_id: String) -> void:
	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	if manifest == null:
		return

	var chapter: VNEngineChapterDef = manifest.find_chapter(chapter_id)
	if chapter == null:
		return

	if chapter.intro_style == "none":
		return

	var overlay: VNEngineCardOverlay = VNEngineMain.instance().get_card_overlay()
	var mode: String = VNEngineCardOverlay.MODE_TITLE
	var card_params: Dictionary = {"title": chapter.title, "subtitle": chapter.subtitle}

	if chapter.intro_style == "eyecatch":
		var image_path := ""
		if story_runner.ctx != null and story_runner.ctx.assets != null and chapter.intro_background != "":
			image_path = story_runner.ctx.assets.resolve("cg", chapter.intro_background)
			if image_path == "":
				image_path = story_runner.ctx.assets.resolve("background", chapter.intro_background)
		if image_path != "":
			mode = VNEngineCardOverlay.MODE_IMAGE
			card_params = {"image_path": image_path}
		else:
			VNEngineLog.warn("VNStageScreen", "intro_style='eyecatch' but intro_background ('%s') could not be resolved, falling back to title card" % chapter.intro_background)

	overlay.open(mode, card_params, chapter.intro_duration)
	await overlay.finished
