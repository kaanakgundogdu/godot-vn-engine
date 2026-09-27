class_name VNEngineCmdMusic
extends VNEngineCommand

func command_name() -> String:
	return "music"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var value := args.strip_edges()

	if value.to_lower() == "stop":
		ctx.state.audio.erase("music")
	else:
		ctx.state.audio["music"] = value
		if value != "":
			VNEngineMain.save_data().unlock_music(value)

	if ctx.audio:
		ctx.audio.play_channel("music", value)
