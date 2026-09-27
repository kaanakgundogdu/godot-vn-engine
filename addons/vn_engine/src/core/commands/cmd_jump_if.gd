class_name VNEngineCmdJumpIf
extends VNEngineCommand

func command_name() -> String:
	return "jump_if"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	if not args.contains("->"):
		VNEngineLog.warn("CmdJumpIf", "Invalid jump_if format: %s" % args)
		return

	var arrow_parts: PackedStringArray = args.split("->", true, 1)
	var condition: String = arrow_parts[0].strip_edges()
	var target: String = arrow_parts[1].strip_edges()

	if condition == "" or target == "":
		VNEngineLog.warn("CmdJumpIf", "Invalid jump_if format: %s" % args)
		return

	if not VNEngineExpressionEvaluator.evaluate(condition, ctx.state.flags):
		return

	var idx: int = ctx.script_res.index_of(target)
	if idx == -1:
		VNEngineLog.warn("CmdJumpIf", "Target not found: %s" % target)
		return

	ctx.runner.play_node(idx)
	ctx.runner._jumped = true
