class_name VNEngineCmdJump
extends VNEngineCommand

func command_name() -> String:
	return "jump"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var target := args.strip_edges()
	var idx := ctx.script_res.index_of(target)

	if idx == -1:
		VNEngineLog.warn("CmdJump", "Target not found: %s" % target)
		return

	ctx.runner.play_node(idx)
	ctx.runner._jumped = true
