class_name VNEngineCmdCall
extends VNEngineCommand

const MAX_CALL_DEPTH := 16

func command_name() -> String:
	return "call"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	if ctx.state.call_stack.size() >= MAX_CALL_DEPTH:
		VNEngineLog.error("CmdCall", "MAX_CALL_DEPTH (%d) exceeded, likely infinite recursion, stopping story" % MAX_CALL_DEPTH)
		ctx.runner.end_story(VNEngineStoryRunner.EndReason.SCRIPT_EXHAUSTED)
		ctx.runner._jumped = true
		return

	var target := args.strip_edges()
	var idx := ctx.script_res.index_of(target)

	if idx == -1:
		VNEngineLog.warn("CmdCall", "Target not found: %s" % target)
		return

	ctx.state.call_stack.append({
		"file": ctx.state.current_file,
		"node_id": ctx.state.current_node_id,
	})

	ctx.runner.play_node(idx)
	ctx.runner._jumped = true
