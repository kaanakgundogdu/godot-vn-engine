class_name VNEngineCmdEyecatch
extends VNEngineCommand

func command_name() -> String:
	return "eyecatch"

func is_blocking() -> bool:
	return true

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdEyecatch", "Missing argument: '@eyecatch' expects an asset id")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	var asset_id := tokens[0]
	var duration := 2.0
	if tokens.size() > 1 and tokens[1].is_valid_float():
		duration = tokens[1].to_float()

	if ctx.assets == null:
		VNEngineLog.warn("CmdEyecatch", "ctx.assets is missing, resolving block immediately")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	var image_path := ctx.assets.resolve("cg", asset_id)
	if image_path == "":
		image_path = ctx.assets.resolve("background", asset_id)

	if image_path == "":
		VNEngineLog.warn("CmdEyecatch", "'%s' was not found as either 'cg' or 'background', resolving block immediately" % asset_id)
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	var vn_main: VNEngineMain = VNEngineMain.instance()
	var overlay: VNEngineCardOverlay = vn_main.get_card_overlay() if vn_main != null else null
	if overlay == null:
		VNEngineLog.warn("CmdEyecatch", "CardOverlay not found, resolving block immediately")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	overlay.open(VNEngineCardOverlay.MODE_IMAGE, {"image_path": image_path}, duration)
	await overlay.finished

	if ctx.bus:
		ctx.bus.resolve_block()
