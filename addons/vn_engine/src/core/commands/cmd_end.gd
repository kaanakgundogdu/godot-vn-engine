class_name VNEngineCmdEnd
extends VNEngineCommand

func command_name() -> String:
	return "end"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var ending_id: String = args.strip_edges()
	ctx.runner.end_story(VNEngineStoryRunner.EndReason.EXPLICIT_END, ending_id)
	ctx.runner._jumped = true
