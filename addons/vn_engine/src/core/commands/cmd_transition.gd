class_name VNEngineCmdTransition
extends VNEngineCommand

func command_name() -> String:
	return "transition"

func is_blocking() -> bool:
	return true

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdTransition", "Missing argument: '@transition' expects a transition kind")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	var kind := tokens[0]
	var duration := 0.5
	if tokens.size() > 1 and tokens[1].is_valid_float():
		duration = tokens[1].to_float()

	var vn_main: VNEngineMain = VNEngineMain.instance()
	if vn_main == null:
		VNEngineLog.warn("CmdTransition", "VNMain not found, resolving block immediately")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	var transition_player: VNEngineTransitionPlayer = vn_main.get_node_or_null("TransitionLayer/TransitionOverlay") as VNEngineTransitionPlayer
	if transition_player == null:
		VNEngineLog.warn("CmdTransition", "TransitionPlayer not found, resolving block immediately")
		if ctx.bus:
			ctx.bus.resolve_block()
		return

	await transition_player.play(kind, {"duration": duration})

	if ctx.bus:
		ctx.bus.resolve_block()
