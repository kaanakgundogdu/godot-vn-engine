class_name VNEngineCmdWait
extends VNEngineCommand

func command_name() -> String:
	return "wait"

func is_blocking() -> bool:
	return true

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var seconds := args.strip_edges().to_float()
	if seconds <= 0.0:
		ctx.bus.resolve_block()
		return
	ctx.runner.get_tree().create_timer(seconds).timeout.connect(ctx.bus.resolve_block)
