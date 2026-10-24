class_name VNEngineCmdSfx
extends VNEngineCommand

func command_name() -> String:
	return "sfx"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	if ctx.audio:
		ctx.audio.play_channel("sfx", args.strip_edges())
