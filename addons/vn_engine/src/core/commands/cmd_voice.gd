class_name VNEngineCmdVoice
extends VNEngineCommand

func command_name() -> String:
	return "voice"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	if ctx.audio:
		ctx.audio.play_channel("voice", args.strip_edges())
