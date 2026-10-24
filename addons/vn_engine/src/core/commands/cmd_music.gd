class_name VNEngineCmdMusic
extends VNEngineCommand

func command_name() -> String:
	return "music"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var parsed: Dictionary = VNEngineAudioSystem.split_fade(args)
	var value: String = parsed["value"]
	var fade: float = parsed["fade"]

	if value.to_lower() == "stop":
		ctx.state.audio.erase("music")
	else:
		ctx.state.audio["music"] = value
		if value != "":
			VNEngineMain.save_data().unlock_music(value)

	if ctx.audio:
		ctx.audio.play_channel("music", value, "", fade)
