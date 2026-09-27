class_name VNEngineCmdReturn
extends VNEngineCommand

func command_name() -> String:
	return "return"

func apply(_args: String, ctx: VNEngineCommandContext) -> void:
	if ctx.state.call_stack.is_empty():
		VNEngineLog.warn("CmdReturn", "call_stack is empty: '@return' used without a matching '@call'")
		ctx.runner.end_story(VNEngineStoryRunner.EndReason.SCRIPT_EXHAUSTED)
		ctx.runner._jumped = true
		return

	var frame: Dictionary = ctx.state.call_stack.pop_back()
	var return_file: String = frame.get("file", "")
	var return_node_id: String = frame.get("node_id", "")

	if return_file != ctx.state.current_file:
		if not ctx.runner._load_script(return_file):
			ctx.runner._jumped = true
			return

	var caller_index := ctx.script_res.index_of(return_node_id)
	if caller_index == -1:
		VNEngineLog.warn("CmdReturn", "Calling node not found: %s" % return_node_id)
		ctx.runner._jumped = true
		return

	var caller_node: VNEngineStoryNode = ctx.script_res.nodes[caller_index]

	if caller_node.next_index == -1:
		ctx.runner.end_story(VNEngineStoryRunner.EndReason.SCRIPT_EXHAUSTED)
		ctx.runner._jumped = true
		return

	ctx.runner.play_node(caller_node.next_index)
	ctx.runner._jumped = true
