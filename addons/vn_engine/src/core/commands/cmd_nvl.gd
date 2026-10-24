class_name VNEngineCmdNvl
extends VNEngineCommand

func command_name() -> String:
	return "nvl"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	match args.strip_edges().to_lower():
		"":
			ctx.runner.set_text_mode("nvl")
		"clear":
			if ctx.runner.is_nvl():
				ctx.runner.clear_nvl_page()
		_:
			VNEngineLog.warn("CmdNvl", "Unknown argument: '%s' (expected clear)" % args)
