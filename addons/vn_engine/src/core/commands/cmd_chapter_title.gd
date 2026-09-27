class_name VNEngineCmdChapterTitle
extends VNEngineCommand

func command_name() -> String:
	return "chapter_title"

func is_blocking() -> bool:
	return true

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens: Array[String] = VNEngineCommand.parse_quoted_args(args)

	var title_text := ""
	var subtitle_text := ""
	var duration := 2.0
	var mode: String = VNEngineCardOverlay.MODE_TITLE
	var card_params: Dictionary = {}

	if tokens.is_empty():
		var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
		if manifest == null:
			VNEngineLog.warn("CmdChapterTitle", "get_manifest() is null, resolving block immediately")
			if ctx.bus:
				ctx.bus.resolve_block()
			return

		var chapter: VNEngineChapterDef = manifest.find_chapter(ctx.state.chapter_id)
		if chapter == null:
			VNEngineLog.warn("CmdChapterTitle", "ChapterDef not found (chapter_id: '%s'), resolving block immediately" % ctx.state.chapter_id)
			if ctx.bus:
				ctx.bus.resolve_block()
			return

		title_text = chapter.title
		subtitle_text = chapter.subtitle
		duration = chapter.intro_duration

		match chapter.intro_style:
			"none":
				if ctx.bus:
					ctx.bus.resolve_block()
				return
			"eyecatch":
				var image_path := ""
				if ctx.assets != null and chapter.intro_background != "":
					image_path = ctx.assets.resolve("cg", chapter.intro_background)
					if image_path == "":
						image_path = ctx.assets.resolve("background", chapter.intro_background)
				if image_path != "":
					mode = VNEngineCardOverlay.MODE_IMAGE
					card_params = {"image_path": image_path}
				else:
					VNEngineLog.warn("CmdChapterTitle", "intro_style='eyecatch' but intro_background ('%s') could not be resolved, falling back to title card" % chapter.intro_background)
	else:
		title_text = tokens[0]
		if tokens.size() > 1:
			subtitle_text = tokens[1]
		if tokens.size() > 2 and tokens[2].is_valid_float():
			duration = tokens[2].to_float()

	var vn_main: VNEngineMain = VNEngineMain.instance()
	var overlay: VNEngineCardOverlay = vn_main.get_card_overlay() if vn_main != null else null
	if overlay == null:
		VNEngineLog.warn("CmdChapterTitle", "CardOverlay not found, resolving block immediately")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	if card_params.is_empty():
		card_params = {"title": title_text, "subtitle": subtitle_text}
	overlay.open(mode, card_params, duration)
	await overlay.finished

	if ctx.bus:
		ctx.bus.resolve_block()
