class_name VNEngineCmdDatecard
extends VNEngineCommand

func command_name() -> String:
	return "datecard"

func is_blocking() -> bool:
	return true

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens: Array[String] = VNEngineCommand.parse_quoted_args(args)
	if tokens.is_empty():
		VNEngineLog.warn("CmdDatecard", "Missing argument: '@datecard' expects at least 1 line of text")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	var line1: String = tokens[0]
	var line2: String = tokens[1] if tokens.size() > 1 else ""
	var line3: String = tokens[2] if tokens.size() > 2 else ""

	var vn_main: VNEngineMain = VNEngineMain.instance()
	var overlay: VNEngineCardOverlay = vn_main.get_card_overlay() if vn_main != null else null
	if overlay == null:
		VNEngineLog.warn("CmdDatecard", "CardOverlay not found, resolving block immediately")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	overlay.open(VNEngineCardOverlay.MODE_DATECARD, {"line1": line1, "line2": line2, "line3": line3})
	await overlay.finished

	if ctx.bus:
		ctx.bus.resolve_block()
