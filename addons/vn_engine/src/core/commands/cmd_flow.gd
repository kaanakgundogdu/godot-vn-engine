class_name VNEngineCmdFlow
extends VNEngineCommand

func command_name() -> String:
	return "flow"

func is_blocking() -> bool:
	return false

func apply(_args: String, ctx: VNEngineCommandContext) -> void:
	var node: VNEngineStoryNode = ctx.runner.get_current_node()
	if node == null or ctx.script_res == null:
		return
	ctx.runner.reach_flow_box("%s.%s" % [ctx.script_res.chapter_id, node.base_id])
