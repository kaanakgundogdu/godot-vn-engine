class_name VNEngineCmdVoice
extends VNEngineCommand

func command_name() -> String:
	return "voice"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var value := args.strip_edges()

	if value.to_lower() == "stop":
		ctx.state.audio.erase("voice")
	else:
		ctx.state.audio["voice"] = value

	if ctx.audio:
		ctx.audio.play_channel("voice", value)
