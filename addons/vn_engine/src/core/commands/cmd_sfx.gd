class_name VNEngineCmdSfx
extends VNEngineCommand

func command_name() -> String:
	return "sfx"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var value := args.strip_edges()

	if value.to_lower() == "stop":
		ctx.state.audio.erase("sfx")
	else:
		ctx.state.audio["sfx"] = value

	if ctx.audio:
		ctx.audio.play_channel("sfx", value)
